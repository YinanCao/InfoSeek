import glob, pickle, os, sys
import numpy as np
import torch, torch.nn as nn, torch.optim as optim
from scipy.optimize import fsolve
import warnings

device = torch.device('cpu')
# device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

from rnnModules import (
    CustomRNN,
    generate_sequences,
    make_input_tensor,
    run_traineval_loop,
    convert_to_numpy_torch,
    convert_to_numpy,
    compute_pRepeatNext,
    compute_uncertaintyDirectedChoice,
)

filepath = "./saved_runs_50000/"  # Directory to save results
# Ensure the save directory exists
os.system("clear")
if not os.path.exists(filepath):
    os.makedirs(filepath)

# Defaults
task = 'guess'       # Default task
lossFunc = 'hybrid'  # Default loss
targetcolor = 1      # Default targetcolor
targetStr = 'ora'
XEntLoss_type = 1    # Default: use out-of-sample 'p_states_ex'
NtrainEpochs = 50000
learningRate = 0.0001
noiseSD = 0.0
hidden_size = 64  # Default number of hidden units

# Check if arguments are provided
if len(sys.argv) > 1:
    subject_id = sys.argv[1]
    if len(sys.argv) > 2:
        hidden_size = int(sys.argv[2])
    if len(sys.argv) > 3:
        task = sys.argv[3]
    if len(sys.argv) > 4:
        lossFunc = sys.argv[4]
    if len(sys.argv) > 5:
        targetcolor = int(sys.argv[5])
    if len(sys.argv) > 6:
        noiseSD = float(sys.argv[6])
    if len(sys.argv) > 7:
        XEntLoss_type = int(sys.argv[7])
else:
    subject_id = "default"  # Fallback if no argument is given
    print("No subject ID provided. Using 'default'.")

if targetcolor == 1:
    targetStr = 'ora'

if targetcolor == -1:
    targetStr = 'blu'

if task == 'guess':
    targetcolor = 1
    targetStr = 'non'

print(f"Running for subject: {subject_id}")
print(f"Hidden size: {hidden_size}")
print(f"RNN for task: {task}")
print(f"Using loss function: {lossFunc}")
print(f"Target color set to: {targetcolor}")
print(f"Noise SD: {noiseSD}")
print(f"XEntLoss_type set to: {XEntLoss_type}")

def run_noisyRNN(hidden_size, noise_value, previous_saved_data: dict={}):
    entropy_suffix = "_pStatesOUT" if XEntLoss_type else "_pStatesALL"
    is_continuation = False
    # RNN:
    input_size  = 2
    output_size = 3
    # Task:
    n_trials   = 20 # max
    n_games    = 4 * 50 # 50 games per condition
    patience   = 500  # waiting time after threshold reached for new one
    # Training Parameters
    max_epochs = NtrainEpochs + 1
    min_epochs = 20
    epochmod   = 50
    # --------------- <end> Constants declaration <end> ---------------
    n_units_str   = 'n%03d' % hidden_size
    batch_str_arr = ["train",  "test"]
 
    # saving variables
    save_dir = filepath
    if is_continuation:
        save_dir = f"./{previous_saved_data['save_dir']}/"
    stop_triggered = False # True if stopping criterion met
    save_initialized = False
    loss_total_min = 1e5
    # Loss function instantiation
    bXEntLoss  = nn.BCELoss()

    print(f"Training with noise value = {noise_value:.2f}...")
    # Begin training loop
    str_datafile = "%s_noise=%03d_loss=%s_subj%s_%s_targcolor=%s_" % (n_units_str, noise_value*100, lossFunc, subject_id, task, targetStr)

    # begin training operations
    rnn = CustomRNN(input_size, hidden_size, output_size, noise_value) # instantiate model
    optimizer = optim.Adam(rnn.parameters(), lr=learningRate, amsgrad=True, eps=1e-6) # attach optimizer to model

    for name, param in rnn.named_parameters():
        if 'weight' in name:
            print(f"{name} - mean: {param.mean().item()}, std: {param.std().item()}")
        elif 'bias' in name:
            print(f"{name} - values: {param.data}")

    # log values for performance and plotting [train, validate]
    if not is_continuation:
        loss_totals  = [[],[]] # [train, test]
        cumR_totals  = [[],[]] # [train, test]
        acc_totals   = [[],[]]
        weights_dict = {} # hold weights for each run that satisfies saving criterion
        l1_totals = [[],[]]
        l2_totals = [[],[]]
    
    torch.set_grad_enabled(True)
    rnn.to(device)

    # loop through epochs
    for epoch in range(max_epochs):
        # loop over training and validation batches
        for ibatch in range(len(batch_str_arr)):
            if ibatch == 0: # for training
                optimizer.zero_grad() # reset gradient
                rnn.train()
            else: # for validation
                rnn.eval()
                
            # init saving vars
            last_epoch_inputs      = {}
            last_epoch_actions     = {}
            last_epoch_p_statesALL = {}
            last_epoch_p_statesOUT = {}
            last_epoch_evidenceALL = {}
            last_epoch_evidenceOUT = {}
            last_epoch_target      = {}
            last_epoch_cumv        = {}
            last_epoch_repeat      = {}
            last_epoch_copt        = {}
            last_epoch_hidden      = {}
            # generate task
            if ibatch==0:
                conditions=[(1, 0), (0, 1), (0, 0), (1, 1)]
                min_len = 2
                max_len = n_trials
                n_samples = 50
                p = 0.2  # constant hazard rate
                x = np.arange(min_len, max_len + 1)
                pmf = (1 - p) ** (x - 1) * p
                pmf = pmf / pmf.sum()
                while True:
                    sequence_lengths = np.random.choice(x, size=n_samples, p=pmf)
                    sequence_lengths = np.sort(sequence_lengths)
                    unique_lengths = np.unique(sequence_lengths)
                    if len(unique_lengths) == len(x):
                        break  # all sequence lengths from 2 to 20 are present
            if ibatch==1:
                conditions=[(1, 0), (0, 1), (0, 0), (1, 1)]
                sequence_lengths = [8, 12, 16, n_trials]
            n_levels    = len(sequence_lengths)
            loss_x_ent  = torch.full((n_levels, 1), torch.nan, device=device)
            policy_loss = torch.full((n_levels, 1), torch.nan, device=device)
            cumR_minibatch = torch.full((n_levels, 1), torch.nan, device=device)
            accuracy    = torch.full((n_levels, 1), torch.nan, device=device)
            ntrl_i      = 0
            # Train or test RNN in minibatches (groups of sequences with varying lengths):
            for ntrl_minibatch in sequence_lengths:
                # rng = make_rng(subject_id, epoch, ibatch, ntrl_i)
                input_tensor_opt1,input_tensor_opt2,target = generate_sequences(ntrl_minibatch, n_games, conditions)
                input_tensors    = make_input_tensor(input_tensor_opt1,input_tensor_opt2)
                out_b            = run_traineval_loop(input_tensors, rnn, device, targetcolor)
                # extract outputs:
                p_states         = out_b["p_states"] # p_states of all sampling trials
                states           = out_b["states"]
                p_states_ex      = out_b["p_states_ex"] # extra, out-of-sample p_states prediction
                states_ex        = out_b["states_ex"]
                chosen_actions   = out_b["chosen_actions"]
                policies         = out_b["policies"]
                hidden           = out_b["h_activat"]
                delta_certainty  = out_b["delta_certainty"]
                chosen_rewards   = out_b["chosen_rewards"] 
                cum_value_T      = out_b["cum_value_T"]

                # Cross-entropy loss:
                if XEntLoss_type:
                    loss_x_ent[ntrl_i] = bXEntLoss(p_states_ex, target) # default: out-of-sample
                else:
                    target_expanded    = target.unsqueeze(0).expand(ntrl_minibatch, -1, -1)
                    loss_x_ent[ntrl_i] = bXEntLoss(p_states, target_expanded)
                
                # Policy [REINFORCE] loss:
                log_probs = torch.log(torch.gather(policies, 2, chosen_actions[1:,:].unsqueeze(-1)).squeeze(-1))
                if task=='bandit':
                    weighted_log_probs = log_probs * chosen_rewards
                if task=='guess':
                    weighted_log_probs = log_probs * delta_certainty
                # print(weighted_log_probs.shape) # [trls, games]
                policy_loss[ntrl_i] = -weighted_log_probs.mean()

                cumR_minibatch[ntrl_i] = chosen_rewards.sum(dim=0).mean()

                # Simulate model-predicted choices:
                c = torch.bernoulli(p_states_ex).type(torch.LongTensor).squeeze()
                accuracy[ntrl_i] = torch.mean(torch.eq(c, target).float())

                if ibatch==1: # in test
                    chosen_act_uncertain           = chosen_actions[1:, :]
                    cv_uncertain                   = cum_value_T[:-1, :, :]
                    last_epoch_inputs[ntrl_i]      = input_tensors  # Save the input tensors of the current epoch
                    last_epoch_actions[ntrl_i]     = chosen_actions  # Save the chosen actions of the current epoch
                    last_epoch_p_statesALL[ntrl_i] = p_states
                    last_epoch_p_statesOUT[ntrl_i] = p_states_ex
                    last_epoch_cumv[ntrl_i]        = cum_value_T
                    last_epoch_target[ntrl_i]      = target
                    last_epoch_evidenceALL[ntrl_i] = states
                    last_epoch_evidenceOUT[ntrl_i] = states_ex
                    last_epoch_hidden[ntrl_i]      = hidden

                ntrl_i += 1
            
            # Choose loss function: 
            if lossFunc   == 'xEntro':
                loss_total = loss_x_ent.mean()
            elif lossFunc == 'pGrad':
                loss_total = policy_loss.mean()
            elif lossFunc == 'hybrid':
                loss_total = loss_x_ent.mean() + policy_loss.mean()
            else:
                warnings.warn(f"Unexpected loss function: {lossFunc}", UserWarning)
                loss_total = None  # or set a default behavior

            cumReward_total = cumR_minibatch.mean()

            loss_totals[ibatch].append(loss_total.item())
            cumR_totals[ibatch].append(cumReward_total.item())

            l1 = loss_x_ent.mean()
            l2 = policy_loss.mean()
            l1_totals[ibatch].append(l1.item())
            l2_totals[ibatch].append(l2.item())

            acc_total = accuracy.mean()
            acc_totals[ibatch].append(acc_total.item())
            
            # backpropagate and optimize (only during training batches)
            if ibatch == 0:
                # torch.autograd.set_detect_anomaly(True)
                loss_total.backward()
                optimizer.step()

        # for output logging purposes ONLY
        if not is_continuation:
            true_epoch = epoch

        # implement stopping check
        if true_epoch > min_epochs: # wait for burn-in period
            if true_epoch == min_epochs + 1:
                epoch_loss_min = true_epoch
                
            if ibatch == 1: # evaluate stopping criterion only on test data
                loss_arr = np.array(loss_totals[1][-patience-1:-1])
                loss_avg = loss_arr.mean() # running mean 
                loss_std = loss_arr.std() # running std
                loss_total_lbound = loss_avg - (3 * loss_std) 
                loss_total_lbound = round(loss_total_lbound, 3)
                
                if loss_total_lbound < loss_total_min:
                    epoch_loss_min = epoch
                    loss_total_min = loss_total_lbound 

            if epoch == max_epochs:
                print('Maximum epoch reached. Stopping training and saving to file...')
                stop_triggered = True

        # Print, log and save
        if (true_epoch % epochmod == 0 and epoch > epochmod-1) or stop_triggered:
            print(f'Current loss: {loss_total.item():.3f} | Accuracy: ({acc_totals[0][-1]:.3f}, {acc_totals[1][-1]:.3f}) | (epoch: {true_epoch})')
            if ibatch==1:
                print('choice: ', chosen_actions[:, 0])
                sp = compute_pRepeatNext(chosen_actions)
                print('p(repeat):', sp[0:10])
                pcopt = compute_uncertaintyDirectedChoice(chosen_act_uncertain, cv_uncertain)
                print("p(uncertain)", pcopt)
                print(lossFunc)

            weights_dict[true_epoch] = {
                            'i2h_w' : rnn.i2h.weight.detach().cpu().numpy().copy(),
                            'h2h_w' : rnn.h2h.weight.detach().cpu().numpy().copy(),
                            'h2h_b' : rnn.h2h.bias.detach().cpu().numpy().copy(),
                            'h2o_w' : rnn.h2o.weight.detach().cpu().numpy().copy(), 
                            }
            
            stored_vals = { "acc_totals"   : acc_totals, 
                            "loss_totals"  : loss_totals, 
                            "cumR_totals"  : cumR_totals, 
                            "weights_dict" : weights_dict,
                            "inputs"       : convert_to_numpy_torch(last_epoch_inputs), 
                            "actions"      : convert_to_numpy_torch(last_epoch_actions),
                            "target"       : convert_to_numpy_torch(last_epoch_target), 
                            "cumv"         : convert_to_numpy_torch(last_epoch_cumv), 
                            "p_statesOUT"  : convert_to_numpy_torch(last_epoch_p_statesOUT),
                            "p_statesALL"  : convert_to_numpy_torch(last_epoch_p_statesALL), 
                            "evidenceOUT"  : convert_to_numpy_torch(last_epoch_evidenceOUT), 
                            "evidenceALL"  : convert_to_numpy_torch(last_epoch_evidenceALL), 
                            "max_epochs"   : max_epochs,
                            "input_size"   : input_size,
                            "output_size"  : output_size,
                            "n_trials"     : n_trials,
                            "n_games"      : n_games,
                            "fundirc"      : convert_to_numpy_torch(last_epoch_copt), 
                            "frepeat"      : convert_to_numpy_torch(last_epoch_repeat),
                            "hidden"       : convert_to_numpy_torch(last_epoch_hidden),
                            "l1_totals"    : l1_totals,
                            "l2_totals"    : l2_totals,
                            }

            # maintain only the last 10 sets of weights
            list_epochs = list(stored_vals['weights_dict'].keys())
            if len(list_epochs) > 10:
                del stored_vals['weights_dict'][list_epochs[0]]

            # save-as-you-go
            if not save_initialized:
                if not is_continuation:
                    list_filenames = glob.glob(f"./{save_dir}/{str_datafile}*{entropy_suffix}.pckl")
                    list_filenames = [name[0:-5] for name in list_filenames]
                
                    # Extract run numbers from filenames
                    list_run_nums = [
                        int(name.split("_run")[-1].split("_")[0])  # Extract the number after "_run" and before the next "_"
                        for name in list_filenames if "_run" in name
                    ]
                    if len(list_run_nums) > 0:
                        last_irun = max(list_run_nums)
                    else:
                        last_irun = -1
                    # set run number
                    irun_file = last_irun + 1

                run_str = f'run{irun_file:02d}'
                str_datafile = f'{str_datafile}{run_str}'
                # turn off run number check
                save_initialized = True
            
            # save file
            with open(f'{save_dir+str_datafile}{entropy_suffix}.pckl', 'wb') as f:
                pickle.dump(stored_vals, f)

        if stop_triggered:
            break
        # </end-of-epoch>
    # </end-of-run>
    # turn off global gradient propagation
    torch.set_grad_enabled(False)

    data_dict = {
        "inputs"      : convert_to_numpy(last_epoch_inputs), 
        "actions"     : convert_to_numpy(last_epoch_actions),
        "target"      : convert_to_numpy(last_epoch_target), 
        "cumv"        : convert_to_numpy(last_epoch_cumv), 
        "p_statesOUT" : convert_to_numpy(last_epoch_p_statesOUT),
        "p_statesALL" : convert_to_numpy(last_epoch_p_statesALL), 
        "evidenceOUT" : convert_to_numpy(last_epoch_evidenceOUT), 
        "evidenceALL" : convert_to_numpy(last_epoch_evidenceALL), 
        "max_epochs"  : max_epochs,
        "input_size"  : input_size,
        "output_size" : output_size,
        "n_trials"    : n_trials,
        "n_games"     : n_games,
        "fundirc"     : convert_to_numpy(last_epoch_copt), 
        "frepeat"     : convert_to_numpy(last_epoch_repeat),
        "hidden"      : convert_to_numpy_torch(last_epoch_hidden),
        "l1_totals"   : l1_totals,
        "l2_totals"   : l2_totals,
    }
    f = open(f'{save_dir+str_datafile}{entropy_suffix}.pckl', 'ab') # Append
    pickle.dump(data_dict, f)
    f.close()

    # Save model weights for future test use
    ckpt_path = f"{save_dir}{str_datafile}{entropy_suffix}_weights.pt"
    torch.save({
        "model_class": "CustomRNN",
        "model_kwargs": {
            "input_dim": input_size,
            "hidden_dim": hidden_size,
            "output_dim": output_size,
            "noise_value": noiseSD,  # doesn't matter; override at load
        },
        "state_dict": rnn.state_dict()
    }, ckpt_path)
    print(f"Saved final trained weights to: {ckpt_path}")

print('Operation terminated.')

if __name__ == "__main__":
    # Parameters
    noise_value = noiseSD  # Noise level
    # Run training
    print("Starting training...")
    run_noisyRNN(hidden_size=hidden_size, 
                 noise_value=noise_value, 
                 previous_saved_data={})
    print("Training completed.")