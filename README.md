# MCInsurance

This Julia package provides Monte Carlo simulations for life
insurance. 

It is intended to supplement a planned book on market consistent risk management in insurance.

## Time model

We differentiate between `n_c` accounting cycles (usually years or quarters) and `n_p` (typically shorter) investment periods. This is handled in the typ  `TimeFrame`

## Stochastic processes

An _n_-dimensional stochastic processes with parameters _p_  assigns for each Monte Carlo scenario _mc_
  and for each _t_  an _n_-dimensional value. The type `Process` provides a common interface for stochastic processes. It has the following sub-types:
  - `ProcessIndex`: Examples sub-types are `Brownian` and `GeomBrownian`. Projected values represent indices. 
  - `ProcessShortrate`:  Example sub-types are `Vasicek`, `CIR` (Cox Ingersoll Ross), `ManualShortRate` (values are provided directly). Projected values represent the (continuously compounding) short rate. 
  
## Capital Market



[![Build Status](https://travis-ci.org/mkriele/MCInsurance.jl.png)](https://travis-ci.org/mkriele/MCInsurance.jl)
