import numpy as np
import torch, torch.nn as nn, torch.optim as optim
from scipy.optimize import fsolve

def convert_to_numpy(tensor_dict):
    return {key: tensor.cpu().numpy() for key, tensor in tensor_dict.items()}

def convert_to_numpy_torch(tensor_dict):
    return {key: tensor.detach().cpu().numpy() for key, tensor in tensor_dict.items()}

def get_cfac(perr, resolution=0.001):
    """
    Calculate the cfac based on the error rate using numerical root finding.
    """
    x = np.arange(-1, 1 + resolution, resolution)  # range of x values
    def cfac_func(b):
        numerator = np.trapezoid(1 / (1 + np.exp(x[x > 0] * b)), x[x > 0])
        denominator = np.trapezoid(1 / (1 + np.exp(x * b)), x)
        return numerator / denominator - perr
    cfac = fsolve(cfac_func, [1.0])  # initial guess for b
    return cfac[0]

def sample_dist(nlevel, llrfac=get_cfac(1/3)): 
    level_list = np.arange(-nlevel, nlevel+1)/nlevel
    llr_list = level_list*llrfac
    p_gen = 1/(1+np.exp(-llr_list))
    p_gen = p_gen/p_gen.sum()
    return p_gen

def generate_sequences(n_trials, n_games, conditions=[(1, 0), (0, 1), (0, 0), (1, 1)], rng=None):
    # configuration
    if rng is None:
        rng = np.random.default_rng()  # fallback default
    ncond = len(conditions)
    n = int(np.floor(n_games/ncond))
    stim_level = np.arange(-.98,1.,.02)
    nlevel = (len(stim_level)-1)/2
    # Calculate the LLR distribution
    llr_dist = sample_dist(nlevel)
    # Initialize lists for stacking stim1, stim2, target
    stim1_all, stim2_all, target_s1, target_s2 = [], [], [], []
    # Loop over conditions (# hidden states (targets)):
    for condition in conditions:
        s1, s2 = condition
        # Generate the samples for current condition
        sample = rng.choice(stim_level, 
                            p=llr_dist, 
                            size=[n, n_trials], 
                            replace=True)
        # Determine stim1_vectors and stim2_vectors
        stim1_vectors = sample if s1 == 1 else -sample # orange(1) means mostly positive values
        stim2_vectors = sample if s2 == 1 else -sample # blue(0) means mostly negative values
        # Stack
        stim1_all.append(stim1_vectors)
        stim2_all.append(stim2_vectors)
        # Create target labels
        target_s1.append(np.full((n,), s1))
        target_s2.append(np.full((n,), s2))
    # Stack all conditions into final tensors
    stim1_all = torch.cat([torch.tensor(x, dtype=torch.float32) for x in stim1_all], dim=0)
    stim2_all = torch.cat([torch.tensor(x, dtype=torch.float32) for x in stim2_all], dim=0)
    target_s1 = torch.cat([torch.tensor(x, dtype=torch.float32) for x in target_s1], dim=0)
    target_s2 = torch.cat([torch.tensor(x, dtype=torch.float32) for x in target_s2], dim=0)
    # Combine target_s1 and target_s2 into a single tensor
    target    = torch.stack((target_s1, target_s2), dim=0) # Shape (2, n_games)
    perm      = torch.randperm(stim1_all.size(0)) # shuffle
    # perm = torch.arange(stim1_all.size(0))
    stim1_all = stim1_all[perm].T
    stim2_all = stim2_all[perm].T
    target    = target[:, perm].T
    # Return the stacked variables
    return stim1_all, stim2_all, target

# Define the RNN model
class CustomRNN(nn.Module):
    def __init__(self, input_dim, hidden_dim, output_dim, noise_value=0.0):
        # bring in methods of nn.Module into RNNModel
        super(CustomRNN, self).__init__()
        # number of units in hidden layer
        self.hidden_dim = hidden_dim
        # noise scalar constant
        self.noise_value = noise_value
        # define layers
        self.i2h = nn.Linear(input_dim,  hidden_dim, bias=False) # input to hidden 
        self.h2h = nn.Linear(hidden_dim, hidden_dim, bias=True)  # hidden to hidden
        self.h2o = nn.Linear(hidden_dim, output_dim, bias=False) # hidden to output
        # define activation functions
        self.tanh = nn.Tanh()

    def forward(self, input, hidden_prev, device):
        inp = self.i2h(input).to(device)
        hid = self.h2h(hidden_prev).to(device)
        
        # update hidden state
        combined = inp + hid
        
        # calculate noise
        if self.noise_value != 0:
            noise_samp = torch.normal(mean=torch.zeros(combined.shape, device=device),
                                      std=torch.ones(combined.shape, device=device)*self.noise_value)
        else:
            noise_samp = torch.zeros(combined.shape, device=device)
        
        # calculate hidden state
        hidden = self.tanh(combined + noise_samp)
        hidden.to(device)
        # calculate output
        output = self.h2o(hidden)
        output.to(device)

        return output, hidden

    def init_hidden(self, batch_size, device):
        # initialize hidden state
        return torch.zeros(batch_size, self.hidden_dim, requires_grad=True, device=device)
    
# Define the RNN model with extra policy layer
class CustomRNN_policy(nn.Module):
    def __init__(self, input_dim, hidden_dim, noise_value=0.0):
        # bring in methods of nn.Module into RNNModel
        super(CustomRNN_policy, self).__init__()
        # number of units in hidden layer
        self.hidden_dim = hidden_dim
        # noise scalar constant
        self.noise_value = noise_value
        # define layers
        self.i2h = nn.Linear(input_dim,  hidden_dim, bias=False) # input to hidden 
        self.h2h = nn.Linear(hidden_dim, hidden_dim, bias=True)  # hidden to hidden
        self.h2s = nn.Linear(hidden_dim, 2, bias=False) # hidden to state outputs
        self.h2p = nn.Linear(hidden_dim, hidden_dim, bias=False) # hidden to policy layer
        self.p2a = nn.Linear(hidden_dim, 1, bias=False) # policy layer to action output

        # define activation functions
        self.tanh = nn.Tanh()

    def forward(self, input, hidden_prev, device):
        inp = self.i2h(input).to(device)
        hid = self.h2h(hidden_prev).to(device)
        
        # update hidden state
        combined = inp + hid
        
        # calculate noise
        if self.noise_value != 0:
            noise_samp = torch.normal(mean=torch.zeros(combined.shape, device=device),
                                      std=torch.ones(combined.shape, device=device)*self.noise_value)
        else:
            noise_samp = torch.zeros(combined.shape, device=device)
        
        # calculate hidden state
        hidden = self.tanh(combined + noise_samp)
        hidden.to(device)
        # calculate output
        output_states = self.h2s(hidden)
        policy_layer = self.tanh(self.h2p(hidden))
        output_action = self.p2a(policy_layer)
        output = torch.cat([output_action, output_states], dim=1)
        output.to(device)
        return output, hidden

    def init_hidden(self, batch_size, device):
        # initialize hidden state
        return torch.zeros(batch_size, self.hidden_dim, requires_grad=True, device=device)

# Creates the input tensor 
def make_input_tensor(input_tensor1, input_tensor2):
    match_opt1 = input_tensor1.unsqueeze(2)
    match_opt2 = input_tensor2.unsqueeze(2)
    output_tensor = torch.cat((match_opt1, match_opt2), dim=2)
    return output_tensor

# Evaluates the model for training or test
def run_traineval_loop(input_tensor, rnn_model, device, targetcolor=1):
    input_dims      = input_tensor.shape
    sequence_length = input_dims[0]
    batch_size      = input_dims[1]
    hidden_size     = rnn_model.h2h.in_features
    # preallocate output tensors
    h_activat        = torch.full((batch_size, hidden_size, sequence_length), torch.nan, device=device)
    responses        = torch.full(input_dims[0:2], torch.nan, device=device)
    respprobs        = torch.full(input_dims[0:2], torch.nan, device=device)
    chosen_actions   = torch.zeros([sequence_length, batch_size], dtype=int)
    cum_value_T      = torch.zeros([sequence_length, batch_size, 2])
    states           = torch.zeros([sequence_length, batch_size,2])
    p_states         = torch.zeros([sequence_length, batch_size,2])
    policies         = torch.full((sequence_length, batch_size,2), torch.nan, device=device)
    certainty_min    = torch.zeros([sequence_length + 1, batch_size])
    chosen_rewards   = torch.full((sequence_length, batch_size), torch.nan, device=device)
    chosen_certainty = torch.full((sequence_length, batch_size), torch.nan, device=device)

    # Initialization
    hidden           = rnn_model.init_hidden(batch_size, device)
    cumulative_input = torch.zeros_like(input_tensor[0,:,:])
    out3D            = torch.zeros([batch_size, 3])

    # run training loop
    for t in range(sequence_length):

        p_action            = torch.sigmoid(out3D[:, 0]) # output for sampling (based on last step)
        respprobs[t, :]     = p_action.squeeze()  # probability; save for output
        action              = torch.bernoulli(p_action).type(torch.LongTensor).squeeze() # 0/1 binary choice
        responses[t, :]     = action # save for output

        train_tensor        = input_tensor[t,:,:] # color
        idx                 = action.unsqueeze(1).to(device) # 0/1 binary choice
        input_at_t          = train_tensor.clone()
        input_at_t[:,:2]    = 0  # Set columns 0 and 1 to zero, so that unchosen remains 0 after next step
        input_at_t          = input_at_t.scatter_(1, idx, train_tensor.gather(1, idx)) # update the chosen
        
        cumulative_input   += input_at_t
        cum_value_T[t,:,:]  = cumulative_input[:, 0:2]
        chosen_actions[t]   = responses[t, :] # save for output
        chosen_rewards[t]   = train_tensor.gather(1, action.unsqueeze(1)).squeeze(1)

        p_states[t,:,:]     = torch.sigmoid(out3D[:, 1:]).squeeze() # 2 RNN outputs for state predictions
        states[t,:,:]       = out3D[:, 1:].squeeze() # raw RNN outputs
        certainty           = torch.abs(states[t,:,:]) # RNN states belief strength
        certainty_min[t]    = torch.min(certainty[:, 0], certainty[:, 1]) # to be maximized
        chosen_certainty[t] = certainty.gather(1, action.unsqueeze(1)).squeeze(1)  # shape (batch, 1)

        pActions            = torch.stack([1 - respprobs[t, :], respprobs[t, :]], dim=1) # probability
        policies[t]         = pActions # save for output

        out3D, hidden       = rnn_model(input_at_t, hidden, device)  # forward pass
        h_activat[:, :, t]  = hidden # save for output

    # Out-of-sample prediction: i.e., trial n + 1
    p_states_ex = torch.sigmoid(out3D[:, 1:]).squeeze() # output for final question (only for 'guess' condition)
    states_ex = out3D[:, 1:].squeeze()
    certainty_ex = torch.abs(states_ex)
    certainty_min[sequence_length] = torch.min(certainty_ex[:, 0], certainty_ex[:, 1]) # to be maximized
    
    policies = policies[1:,:,:] # trl1,2,3.., trl0 is random
    delta_certainty = certainty_min[2:, :] - certainty_min[1:-1, :] 
    delta_certainty = delta_certainty.detach()
    # certainty_min = certainty_min[2:, :].detach()
    chosen_rewards = chosen_rewards[1:, :] * targetcolor

    out = { 'p_states':         p_states,
            'p_states_ex':      p_states_ex, 
            'states':           states,
            'states_ex':        states_ex,
            'respprobs':        respprobs,
            'responses':        responses,
            'h_activat':        h_activat,
            'cum_value_T':      cum_value_T,
            'chosen_actions':   chosen_actions,
            'policies' :        policies,
            'certainty_min':    certainty_min,
            'delta_certainty':  delta_certainty,
            'chosen_rewards':   chosen_rewards,
            'chosen_certainty': chosen_certainty,
            }
    return out

# Evaluates the model for training or test
def run_traineval_loop_onehot(input_tensor, rnn_model, device, targetcolor=1):
    input_dims      = input_tensor.shape
    sequence_length = input_dims[0]
    batch_size      = input_dims[1]
    hidden_size     = rnn_model.h2h.in_features
    # preallocate output tensors
    h_activat        = torch.full((batch_size, hidden_size, sequence_length), torch.nan, device=device)
    responses        = torch.full(input_dims[0:2], torch.nan, device=device)
    respprobs        = torch.full(input_dims[0:2], torch.nan, device=device)
    chosen_actions   = torch.zeros([sequence_length, batch_size], dtype=int)
    cum_value_T      = torch.zeros([sequence_length, batch_size, 2])
    states           = torch.zeros([sequence_length, batch_size,2])
    p_states         = torch.zeros([sequence_length, batch_size,2])
    policies         = torch.full((sequence_length, batch_size,2), torch.nan, device=device)
    certainty_min    = torch.zeros([sequence_length + 1, batch_size])
    chosen_rewards   = torch.full((sequence_length, batch_size), torch.nan, device=device)
    chosen_certainty = torch.full((sequence_length, batch_size), torch.nan, device=device)

    # Initialization
    hidden           = rnn_model.init_hidden(batch_size, device)
    cumulative_input = torch.zeros_like(input_tensor[0,:,:])
    out3D            = torch.zeros([batch_size, 3])

    # run training loop
    for t in range(sequence_length):

        p_action            = torch.sigmoid(out3D[:, 0]) # output for sampling (based on last step)
        respprobs[t, :]     = p_action.squeeze()  # probability; save for output
        action              = torch.bernoulli(p_action).type(torch.LongTensor).squeeze() # 0/1 binary choice
        responses[t, :]     = action # save for output

        train_tensor        = input_tensor[t,:,:] # color
        idx                 = action.unsqueeze(1).to(device) # 0/1 binary choice
        input_at_t          = train_tensor.clone()
        input_at_t[:,:2]    = 0  # Set columns 0 and 1 to zero, so that unchosen remains 0 after next step
        input_at_t          = input_at_t.scatter_(1, idx, train_tensor.gather(1, idx)) # update the chosen
        
        cumulative_input   += input_at_t
        cum_value_T[t,:,:]  = cumulative_input[:, 0:2]
        chosen_actions[t]   = responses[t, :] # save for output
        chosen_rewards[t]   = train_tensor.gather(1, action.unsqueeze(1)).squeeze(1)

        p_states[t,:,:]     = torch.sigmoid(out3D[:, 1:]).squeeze() # 2 RNN outputs for state predictions
        states[t,:,:]       = out3D[:, 1:].squeeze() # raw RNN outputs
        certainty           = torch.abs(states[t,:,:]) # RNN states belief strength
        certainty_min[t]    = torch.min(certainty[:, 0], certainty[:, 1]) # to be maximized
        chosen_certainty[t] = certainty.gather(1, action.unsqueeze(1)).squeeze(1)  # shape (batch, 1)

        pActions            = torch.stack([1 - respprobs[t, :], respprobs[t, :]], dim=1) # probability
        policies[t]         = pActions # save for output

        # one-hot actions:
        one_hot_action = torch.nn.functional.one_hot(
            action.to(torch.long), 
            num_classes=input_at_t.size(-1)
        ).to(dtype=input_at_t.dtype, device=input_at_t.device)

        combined = torch.cat([input_at_t, one_hot_action], dim=-1)  # [200, 4]

        out3D, hidden       = rnn_model(combined, hidden, device)  # forward pass
        h_activat[:, :, t]  = hidden # save for output

    # Out-of-sample prediction: i.e., trial n + 1
    p_states_ex = torch.sigmoid(out3D[:, 1:]).squeeze() # output for final question (only for 'guess' condition)
    states_ex = out3D[:, 1:].squeeze()
    certainty_ex = torch.abs(states_ex)
    certainty_min[sequence_length] = torch.min(certainty_ex[:, 0], certainty_ex[:, 1]) # to be maximized
    
    policies = policies[1:,:,:] # trl1,2,3.., trl0 is random
    delta_certainty = certainty_min[2:, :] - certainty_min[1:-1, :] 
    delta_certainty = delta_certainty.detach()
    # certainty_min = certainty_min[2:, :].detach()
    chosen_rewards = chosen_rewards[1:, :] * targetcolor

    out = { 'p_states':         p_states,
            'p_states_ex':      p_states_ex, 
            'states':           states,
            'states_ex':        states_ex,
            'respprobs':        respprobs,
            'responses':        responses,
            'h_activat':        h_activat,
            'cum_value_T':      cum_value_T,
            'chosen_actions':   chosen_actions,
            'policies' :        policies,
            'certainty_min':    certainty_min,
            'delta_certainty':  delta_certainty,
            'chosen_rewards':   chosen_rewards,
            'chosen_certainty': chosen_certainty,
            }
    return out

# Evaluates the model for training or test
def run_traineval_loop_forcedActions(input_tensor, rnn_model, action_forced, device, targetcolor=1):
    input_dims      = input_tensor.shape
    sequence_length = input_dims[0]
    batch_size      = input_dims[1]
    hidden_size     = rnn_model.h2h.in_features
    # preallocate output tensors
    h_activat        = torch.full((batch_size, hidden_size, sequence_length), torch.nan, device=device)
    responses        = torch.full(input_dims[0:2], torch.nan, device=device)
    respprobs        = torch.full(input_dims[0:2], torch.nan, device=device)
    chosen_actions   = torch.zeros([sequence_length, batch_size], dtype=int)
    cum_value_T      = torch.zeros([sequence_length, batch_size, 2])
    states           = torch.zeros([sequence_length, batch_size,2])
    p_states         = torch.zeros([sequence_length, batch_size,2])
    policies         = torch.full((sequence_length, batch_size,2), torch.nan, device=device)
    certainty_min    = torch.zeros([sequence_length + 1, batch_size])
    chosen_rewards   = torch.full((sequence_length, batch_size), torch.nan, device=device)
    chosen_certainty = torch.full((sequence_length, batch_size), torch.nan, device=device)

    # Initialization
    hidden           = rnn_model.init_hidden(batch_size, device)
    cumulative_input = torch.zeros_like(input_tensor[0,:,:])
    out3D            = torch.zeros([batch_size, 3])

    # run training loop
    for t in range(sequence_length):

        # p_action            = torch.sigmoid(out3D[:, 0]) # output for sampling (based on last step)
        # respprobs[t, :]     = p_action.squeeze()  # probability; save for output
        # action              = torch.bernoulli(p_action).type(torch.LongTensor).squeeze() # 0/1 binary choice

        action              = action_forced[t]
        responses[t, :]     = action # save for output

        train_tensor        = input_tensor[t,:,:] # color
        idx                 = action.unsqueeze(1).to(device) # 0/1 binary choice
        input_at_t          = train_tensor.clone()
        input_at_t[:,:2]    = 0  # Set columns 0 and 1 to zero, so that unchosen remains 0 after next step
        input_at_t          = input_at_t.scatter_(1, idx, train_tensor.gather(1, idx)) # update the chosen
        
        cumulative_input   += input_at_t
        cum_value_T[t,:,:]  = cumulative_input[:, 0:2]
        chosen_actions[t]   = responses[t, :] # save for output
        chosen_rewards[t]   = train_tensor.gather(1, action.unsqueeze(1)).squeeze(1)

        p_states[t,:,:]     = torch.sigmoid(out3D[:, 1:]).squeeze() # 2 RNN outputs for state predictions
        states[t,:,:]       = out3D[:, 1:].squeeze() # raw RNN outputs
        certainty           = torch.abs(states[t,:,:]) # RNN states belief strength
        certainty_min[t]    = torch.min(certainty[:, 0], certainty[:, 1]) # to be maximized
        chosen_certainty[t] = certainty.gather(1, action.unsqueeze(1)).squeeze(1)  # shape (batch, 1)

        # pActions            = torch.stack([1 - respprobs[t, :], respprobs[t, :]], dim=1) # probability
        # policies[t]         = pActions # save for output

        out3D, hidden       = rnn_model(input_at_t, hidden, device)  # forward pass
        h_activat[:, :, t]  = hidden # save for output

    # Out-of-sample prediction: i.e., trial n + 1
    p_states_ex = torch.sigmoid(out3D[:, 1:]).squeeze() # output for final question (only for 'guess' condition)
    states_ex = out3D[:, 1:].squeeze()
    certainty_ex = torch.abs(states_ex)
    certainty_min[sequence_length] = torch.min(certainty_ex[:, 0], certainty_ex[:, 1]) # to be maximized
    
    policies = policies[1:,:,:] # trl1,2,3.., trl0 is random
    delta_certainty = certainty_min[2:, :] - certainty_min[1:-1, :] 
    delta_certainty = delta_certainty.detach()
    certainty_min = certainty_min[2:, :].detach()
    chosen_rewards = chosen_rewards[1:, :] * targetcolor

    out = { 'p_states':         p_states,
            'p_states_ex':      p_states_ex, 
            'states':           states,
            'states_ex':        states_ex,
            'respprobs':        respprobs,
            'responses':        responses,
            'h_activat':        h_activat,
            'cum_value_T':      cum_value_T,
            'chosen_actions':   chosen_actions,
            'policies' :        policies,
            'certainty_min':    certainty_min,
            'delta_certainty':  delta_certainty,
            'chosen_rewards':   chosen_rewards,
            'chosen_certainty': chosen_certainty,
            }
    return out

def compute_uncertaintyDirectedChoice(chosen_act, cumulative_values):
    n_trials, batch_size = chosen_act.shape
    mcopt = []
    for iseq in range(batch_size):
        ch = chosen_act[:, iseq]  # Get the choices for this sequence
        cv = cumulative_values[:, iseq, :]
        # Find the index of the minimum absolute value in each row of cv
        _, tempopt = torch.min(torch.abs(cv), dim=1)  # tempopt stores indices of min values
        # Compare choices (ch) to the minimum index (tempopt)
        choice_matches = (ch == tempopt).float()  # 1 if match, 0 otherwise
        # Handle cases where abs(cv[:, 0]) == abs(cv[:, 1]) (or more generally any equal options)
        equal_mask = (torch.abs(cv[:, 0]) == torch.abs(cv[:, 1]))
        choice_matches[equal_mask] = float('nan')  # Assign NaN to rows where options are equal
        # Store results for this sequence
        mcopt.append(choice_matches)
    pcopt = torch.nanmean(torch.stack(mcopt, dim=1), dim=1)
    return pcopt

def compute_pRepeatNext(chosen_act):
    """
    Compute the probability of repeating an action as a function of 
    how many times the corresponding option has been chosen so far.
    """
    n_trials, batch_size = chosen_act.shape
    # Initialize tensors
    sprevch = torch.full((batch_size, n_trials), torch.nan)
    srepeat = torch.full((batch_size, n_trials), torch.nan)
    prepnext = torch.full((n_trials,), torch.nan)
    # Loop over sequences
    for iseq in range(batch_size):
        ch = chosen_act[:, iseq]  # Get the choices for this sequence
        for ismp in range(n_trials - 1):
            # Count how many times the current choice has been selected up to this point
            sprevch[iseq, ismp] = torch.sum(ch[:ismp] == ch[ismp]).item() + 1
            # Check if the current choice repeats in the next trial
            srepeat[iseq, ismp] = ch[ismp] == ch[ismp + 1]
    # Handle `nan` values manually for the maximum
    valid_sprevch = sprevch[~torch.isnan(sprevch)]  # Filter out nan values
    if valid_sprevch.numel() > 0:  # Check if there are valid values
        max_sprevch = torch.max(valid_sprevch)
        # print(max_sprevch)
        # Compute spstay: probability of staying as a function of prior choices
        for idx in range(1, int(max_sprevch.item()) + 1):  # Range starts from 1 to max(sprevch)
            ich = torch.where(sprevch == idx)  # Find indices where sprevch equals idx
            if len(ich[0]) > 0:  # Check if there are any matches
                # print(srepeat[ich])
                prepnext[idx - 1] = torch.nanmean(srepeat[ich]).item()
    return prepnext

def compute_targetDirectedChoice(chosen_act, cumulative_values):
    n_trials, batch_size = chosen_act.shape
    mcopt = []
    for iseq in range(batch_size):
        ch = chosen_act[:, iseq]  # Get the choices for this sequence
        cv = cumulative_values[:, iseq, :]
        # Find the index of the minimum absolute value in each row of cv
        _, tempopt = torch.max(cv, dim=1)  # tempopt stores indices of min values
        # Compare choices (ch) to the minimum index (tempopt)
        choice_matches = (ch == tempopt).float()  # 1 if match, 0 otherwise
        # Handle cases where abs(cv[:, 0]) == abs(cv[:, 1]) (or more generally any equal options)
        equal_mask = (torch.abs(cv[:, 0]) == torch.abs(cv[:, 1]))
        choice_matches[equal_mask] = float('nan')  # Assign NaN to rows where options are equal
        # Store results for this sequence
        mcopt.append(choice_matches)
    pvopt = torch.nanmean(torch.stack(mcopt, dim=1), dim=1)
    return pvopt

def make_rng(subject_id: str, epoch: int, ibatch: int, ntrl_i: int) -> np.random.Generator:
    """
    Creates a reproducible RNG seeded by (subject_id, epoch, ibatch, ntrl_i).
    """
    subject_int = int(subject_id) if subject_id.isdigit() else sum(ord(c) for c in subject_id)
    seed_seq = np.random.SeedSequence([subject_int, epoch, ibatch, ntrl_i])
    return np.random.default_rng(seed_seq)

def simulate_optimal(chosen_act, inputs, task):
    n_trials, batch_size = chosen_act.shape
    cumv_optimal = np.zeros((n_trials+1, batch_size, 2))
    act_optimal  = np.full([n_trials, batch_size],np.nan)
    
    for iseq in range(batch_size):
        ch = chosen_act[0, iseq] # Get the choices for this sequence
        cumv = np.zeros([2,])
        for trl in range(n_trials):
            act_optimal[trl, iseq] = ch
            v_zero = np.zeros([2,])
            v_zero[ch] = inputs[trl, iseq, ch]
            cumv += v_zero
            if task=='guess':
                DV = np.abs(cumv)
            else:
                DV = cumv
            if DV[0] == DV[1]:
                # idx = np.random.choice([0, 1])
                if trl < n_trials - 1:
                    idx = chosen_act[trl + 1, iseq]
                else:
                    idx = np.random.choice([0, 1])  # fallback if at last trial
            else:
                if task=='guess':
                    idx = np.argmin(DV)
                else:
                    idx = np.argmax(DV)
            ch = idx
            cumv_optimal[trl + 1,iseq,:] = cumv
        
    return cumv_optimal, act_optimal


def sim_modelbound_noisyleaky(betav, betac, betar, theta, omega, gamma, delta_c, delta_u, sigma,
    colorop, targetc, choices=None, rng=None, cfac=get_cfac(1/3)
):
    # Convert colorop to NumPy
    if hasattr(colorop, "detach"):  # torch tensor
        colorop_np = colorop.detach().cpu().numpy()
    else:
        colorop_np = np.asarray(colorop)

    nsmp, nseq, nopt = colorop_np.shape
    assert nopt == 2, "colorop must have last dim size 2 (two options)."

    # Normalize targetc to per-sequence NumPy array
    if np.isscalar(targetc):
        targetc_vec = np.full(nseq, float(targetc), dtype=float)
    else:
        targetc_vec = np.asarray(targetc, dtype=float).reshape(-1)
        assert targetc_vec.shape[0] == nseq, "targetc length must equal number of games (nseq)."

    if rng is None:
        rng = np.random.default_rng()

    mch = [np.full(nsmp, np.nan, dtype=np.float64) for _ in range(nseq)]

    for iseq in range(nseq):
        # Beliefs over options across time
        xc = np.full((nsmp, 2), np.nan, dtype=float)
        xc[0, :] = 0.0

        # Bound-control flags for each option
        bc = np.array([True, True], dtype=bool)
        if theta == 0:
            bc[:] = False  # disable bound control from the outset

        # First trial choice: if 'choices' provided use it (0/1 -> 1/2), else random {1,2}
        if choices is not None:
            v01 = choices[0, iseq]
            v01 = int(v01.item()) if hasattr(v01, "item") else int(np.asarray(v01))
            if v01 not in (0, 1):
                raise ValueError(f"choices[0, {iseq}] must be 0 or 1")
            ch0 = v01 + 1
        else:
            ch0 = rng.integers(1, 3)
        mch[iseq][0] = ch0

        # Per-sequence target sign
        tgt = targetc_vec[iseq]

        # Trial loop (start at second trial, index 1)
        for ismp_idx in range(1, nsmp):
            ch = int(mch[iseq][ismp_idx - 1])           # previous choice in {1,2}
            ch_idx = ch - 1                              # 0-based
            un_idx = 1 - ch_idx                          # the other option

            # Evidence from previous trial for the chosen option
            ev_ch_prev = colorop_np[ismp_idx - 1, iseq, ch_idx]

            # Belief updates with noise on chosen, then leak on both
            xc[ismp_idx, ch_idx] = xc[ismp_idx - 1, ch_idx] + ev_ch_prev * cfac + rng.normal(0.0, sigma)
            xc[ismp_idx, un_idx] = xc[ismp_idx - 1, un_idx]

            xc[ismp_idx, ch_idx] *= (1.0 - delta_c)
            xc[ismp_idx, un_idx] *= (1.0 - delta_u)

            # Update bound state for the chosen option if still under bound
            if bc[ch_idx]:
                if gamma == 0:
                    xt = theta
                else:
                    # Draw Gamma with mean=theta and sd=gamma
                    # shape k = (theta/gamma)^2, scale = gamma^2/theta
                    k = (theta / gamma) ** 2
                    scale = (gamma ** 2) / theta
                    # Guard for potential numerical issues if theta is tiny
                    if theta <= 0:
                        xt = 0.0
                    else:
                        xt = rng.gamma(shape=k, scale=scale)
                bc[ch_idx] = np.abs(xc[ismp_idx, ch_idx]) < xt

            # Decision variable
            dv = betav * (xc[ismp_idx, 0] - xc[ismp_idx, 1]) * tgt
            dv -= betac * (np.abs(xc[ismp_idx, 0]) - np.abs(xc[ismp_idx, 1]))
            dv += betar * (3 - 2 * ch)  # +1 if ch==1, -1 if ch==2

            # Choice probabilities
            if bc[ch_idx]:
                pc1 = omega if ch_idx == 0 else (1.0 - omega)
            else:
                # Logistic for option 1; option 2 is complementary
                # Clip dv to avoid overflow in exp
                dv_clip = np.clip(dv, -700, 700)

                if betac > 100:
                    b12 = np.abs(xc[ismp_idx, 0]) - np.abs(xc[ismp_idx, 1])
                    pc1 = 1 if b12 < 0 else 0
                else:
                    pc1 = 1.0 / (1.0 + np.exp(-dv_clip))

            # Sample next choice: 1 with prob pc1, else 2
            mch[iseq][ismp_idx] = 1 if rng.random() <= pc1 else 2

            # If switched away from previous choice, disable bound for the previous option
            if int(mch[iseq][ismp_idx]) != ch:
                bc[ch_idx] = False

        # Cast to int
        mch[iseq] = mch[iseq].astype(np.int64)

    mch_mat01 = np.stack(mch, axis=1) - 1   # shape (nsmp, nseq)

    return mch_mat01, mch
