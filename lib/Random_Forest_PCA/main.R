# Set directory


# Load functions
source("random forest_train_test_cv.R")
source("../PCA.R")


# Load features and label
library(data.table)
library(dplyr)
feature <- fread("../../output/hog_feature+sift.csv", header = TRUE)
label <- fread("../../data/labels.csv")
label <- c(t(label))
feature <- tbl_df(t(feature)) 


######### Tuning parameters #########

# Tune parameter of PCA: threshold
threshold_value <- seq(0.1, 0.9, by=0.1)

for (i in 1:length(threshold_value)){
  cat(i)
  pca_thre <- feature.pca(dat_feature = feature, threshold = threshold_value[i])
}

# Tune parameter for random forest: ntree
ntree <- seq(10, 400, by=20) 


err_cv_rf <- matrix(NA, ncol=length(ntree), nrow=length(threshold_value))
err_sd_rf <- matrix(NA, ncol=length(ntree), nrow=length(threshold_value))

for (i in 1:length(threshold_value)){
  cat("i=", i, "\n")
  threshold <- threshold_value[i]
  
  # Use the already saved extracted pca features with threshold value
  load(paste("../../output/extracted.pca", threshold, ".RData"))
  
  for (j in 1:length(ntree)){
    cat("j=", j, "\n")
    result <- rf_cv(dat_train = pca_thre, label_train = label, K = 5, ntree = ntree[j])
    err_cv_rf[i,j] <- result[1]
    err_sd_rf[i,j] <- result[2]
  }
}  

# Transform into dataframe
err_cv_rf_df <- data.frame(err_cv_rf)
colnames(err_cv_rf_df) <- ntree
rownames(err_cv_rf_df) <- threshold_value

err_sd_rf_df <- data.frame(err_sd_rf) 
colnames(err_sd_rf_df) <- ntree
rownames(err_sd_rf_df) <- threshold_value

# Reshape previous dataframe into narrow form
library(tidyr)
library(ggplot2)
cleaned_err_cv_rf <- err_cv_rf_df %>% 
  tibble::rownames_to_column("threshold_value") %>% 
  gather(key = ntree, value = val, -threshold_value)

cleaned_err_sd_rf <- err_sd_rf_df %>% 
  tibble::rownames_to_column("threshold_value") %>% 
  gather(key = ntree, value = val, -threshold_value)

# Save results
save(err_cv_rf, err_cv_rf_df, cleaned_err_cv_rf, file="../../output/err_cv_rf.RData")
save(err_sd_rf, err_sd_rf_df, cleaned_err_sd_rf, file="../../output/err_sd_rf.RData") 

# Visualize CV results
png(filename=paste("../../figs/cv_result_rf.png"))
ggplot(cleaned_err_cv_rf) +
  geom_line(aes(x=as.numeric(ntree), y=val, color=threshold_value)) +
  ggtitle("CV Results of Random Forest") +
  xlab("ntree")+
  ylab("error rate")
dev.off()
  
# Choose the best parameter value from visualization
best_pca_thre <- 0.2
best_ntree <- 350


############# Retrain model with tuned parameters ##############

# train the model with the entire training set
tm_train_rf <- system.time(fit_train_rf <- rf_pca_train(dat_train=feature, label_train=label, ntree=best_ntree, pca_threshold=best_pca_thre))
save(fit_train_rf, file="../../output/fit_train_rf.RData")


### Make prediction 
pc_test <- feature.pca(dat_feature = dat_test, threshold = best_pca_thre)
tm_test_rf <- system.time(pred_test_rf <- rf_test(fit_train = fit_train_rf, dat_test = pc_test))
save(pred_test_rf, file="../../output/pred_test_rf.RData")
