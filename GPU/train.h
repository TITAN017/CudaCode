#ifndef TRAIN_H
#define TRAIN_H


#include "sequential.h"


void train(Sequential_GPU seq, float *inp, float *targ, int bs, int n_in, int n_epochs);


#endif
