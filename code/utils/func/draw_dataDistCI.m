function draw_dataDistCI(data,cfg)

if ~isfield(cfg, 'starcolor')
    cfg.starcolor = 'r';
end

if ~isfield(cfg, 'conn')
    cfg.conn = 1;
end


    noise = [];
    for k = 1:size(data,2)
        tmp    = data(:,k);
        [f,xi] = ksdensity(tmp);
        f      = f./max(f);
        ff     = [];
        for j = length(tmp):-1:1
            [~,id] = min(abs(tmp(j)-xi));
            ff(j)  = f(id);
        end
        for j = length(ff):-1:1
            noise(j,k) = randn*ff(j)/cfg.noiseSD;
        end
    end

    mean_CI = zeros(size(data,2), 3); % For mean ± 95% CI
    median_IQR = zeros(size(data,2), 3); % For median ± IQR
    for k = size(data,2):-1:1
        col_data = data(~isnan(data(:,k)),k);
        % 1) Mean ± 95% CI
        mean_data = mean(col_data);
        sem_data = std(col_data)/sqrt(length(col_data));
        ci_95 = 1.96 * sem_data; % 95% confidence interval margin

        % tval = tinv(0.975, length(col_data) - 1);  % 0.975 for 2-tailed 95%
        % ci_95 = tval * sem_data;

        mean_CI(k,:) = [mean_data-ci_95,mean_data,mean_data+ci_95];
        % 2) Median ± Interquartile Range (IQR)
        median_data = median(col_data);
        iqr_data = iqr(col_data); % Interquartile range
        min_bound = min(col_data);
        max_bound = max(col_data);
        % Calculate lower and upper bounds of the IQR-based range
        lower_bound = max(min_bound,median_data-iqr_data/2);
        upper_bound = min(max_bound,median_data+iqr_data/2);
        median_IQR(k, :) = [lower_bound, median_data, upper_bound];
        
        % test data against 0
    end
   
    nk    = size(data,2);
    pairs = nchoosek(1:nk,2);
    P0    = ones(1,size(pairs, 1));
    P1    = ones(1,size(pairs, 1));
    for i = 1:size(pairs, 1)
        d = data(:,pairs(i,1)) - data(:,pairs(i,2));
        P0(i) = signrank(d, 0,'tail', cfg.side);
        [~, P1(i)] = ttest(d, 0,'tail', cfg.side);
    end
    
    if cfg.CItype==1
        sum_stats = median_IQR;
        pval = P0;
    else
        sum_stats = mean_CI;
        pval = P1;
    end
    
    pval(isnan(pval)) = 1;
    
    pval = Bonf_Holm_yc(pval);
    pval
    
    sig = pval<.05;
    shift = [+1,-1,0]*0.0;
    if nk>2, shift = shift*0+0.2;end

    if cfg.conn
        plot(sum_stats(:,2),'LineWidth',2,'Color',ones(1,3)*0.5); hold on
    end
    
    count = 0;
    for k = 1:size(data,2)
        st = sum_stats(k,:);
        if ~all(st==0)
            count = count + 1;
            scatter(k+noise(:,k),data(:,k),cfg.markersize,'o',...
            'MarkerFaceColor', cfg.color(k,:), ...
            'MarkerEdgeColor', cfg.color(k,:), ...
            'MarkerFaceAlpha', cfg.dotalpha, ... % Set alpha transparency for marker face
            'MarkerEdgeAlpha', cfg.dotalpha);    % Set alpha transparency for marker edge
            hold on;
            scatter(k+shift(k),st(2),cfg.markersize*5,'o',...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', cfg.color(k,:), ...
            'MarkerFaceAlpha', 1, ...
            'MarkerEdgeAlpha', 1);
            plot([k,k]+shift(k),[st(1),st(3)],'-',...
                'color',cfg.color(k,:),'linewidth',3)
        end
    end
    
    d = -cfg.sigy*1/20;
    if count==size(data,2)
        for i = 1:numel(sig)
            if sig(i)
               text(mean(pairs(i,:)+shift(pairs(i,:))),cfg.sigy+(i-1)*d,'*','HorizontalAlignment','Center',...
                'BackGroundColor','none','VerticalAlignment','middle',...
                'fontsize',16,'color',cfg.starcolor); hold on;
                plot(pairs(i,:)+shift(pairs(i,:)),...
                    ones(1,2)*(cfg.sigy+(i-1)*d),'linewidth',1,'color','k')

                x=pairs(i,:)+shift(pairs(i,:));
                y=cfg.sigy+(i-1)*d;
                yl = ylim;                 % get current y-axis limits
                yrange = yl(2) - yl(1);    % total y-axis range
                leng = 0.02 * yrange;
                for kk=1:length(x)
                plot(x(kk)*ones(1,2), [cfg.sigy+(i-1)*d,cfg.sigy+(i-1)*d-leng],'linewidth',1,'color','k')
                end



%             else
%                text(mean(pairs(i,:))+shift(i),cfg.sigy+(i-1)*d,'n.s.','HorizontalAlignment','Center',...
%                 'BackGroundColor','none','VerticalAlignment','bottom',...
%                 'fontsize',16,'color','k'); hold on;
            end
            
        end
    end
    
    
end