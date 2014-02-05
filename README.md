# MCInsurance

This Julia package provides multi-period Monte Carlo simulations for life insurance.

The primary application is the preparation of examples for a planned co-authored book on market consistent risk management in insurance.[^1]

##Organization of the model

The model is organized in several blocks.

###Time model

We differentiate between `n_c` accounting cycles (usually years or quarters) and `n_p` (typically shorter) investment periods. This is handled in the type  `TimeFrame`.

###Stochastic processes

The type `Process` provides a common interface for stochastic processes. It has the following sub-types:

* `ProcessIndex`: Examples sub-types are `Brownian` and `GeomBrownian`. Projected values represent _n_-dimensional indices.
* `ProcessShortRate`:  Example sub-types are `Vasicek`, `CIR` (Cox Ingersoll Ross), `ManualShortRate` (values are provided directly). Projected values represent the (continuously compounding) short rate.

An _n_-dimensional stochastic process with parameters _p_  assigns to each Monte Carlo scenario `mc` and to each period `t`  an _n_-dimensional value `proc.v_bop[mc,t,:]`. This value represent the value of the index or the 1-period yield at the beginning of period `t`. The value  `proc.yield[mc,t,:]` always represents a yield, provided it can be defined.
  
###Capital market

The type `CapMkt` models a simple capital market that is based on several stochastic processes. These processes are linked through a time dependent  noise matrix. At present, risk-free interest rates and stock indices have been implemented. Cash is modeled through a process of type `ProcessShortRate`. 

###Asset allocation

The investment activities of the insurer are captured by the type `Invest`.  It contains a capital market and several investment groups  which corresponds to different asset types.  At this point in time, the investment groups `IGCash`, `IGRiskfreeBonds`, `IGStocks` are implemented.  It is possible, to have several investment groups of the same type but with different characteristics, for instance in order to implement _general accounts_ and _separate accounts_.

The asset allocation is driven via market values, i.e, at the beginning of each time period   each investment group (and each financial instrument within each investment group) is allocated a market value, given as a percentage of the total market value of  existing assets.  

For the projection of risk-free bonds the following simplifications are made:

* book values are ignored,
* it is assumed that a coupon is paid each period,
*  individual coupons for bonds of the same remaining duration are replaced by (approximate) average coupons.

These approximations help keeping the number of risk-free bonds to be modeled down. 

###Insurance contracts

Insurance products are modeled through profiles for premium, costs, and benefits. This makes it possible to define different insurance products through inputs.  For each insurance product there is an associated  function that models lapse probabilities.  At present, only linear lapse functions are implemented.

Policy holders and insurance contracts are given as different inputs, and it is possible to associate with one policy holder several insurance products.  However, this association will be lost, once the insurance contracts are condensed into [buckets](#buckets).

For each insurance contract a _conditional cashflow_ is calculated, which for each period provides the cashflows, that would occur, if they were triggered by the corresponding biometric event.[^2] 

###Buckets {#buckets}

Similar contracts are condensed into instances `bucket` of type `Bucket`. Each `bucket` is associated with a category `bucket.cat` of insurance conrtracts. At present, `bucket.cat` holds the following information:

* age of policy holder at the beginning of the projection,
* gender of the policy holder,
* mortality table,
* risk class.

All  contracts matching `bucket.cat` are combined into a single conditional cashflow.  The bucket also records how many insurance contracts have been combined (`bucket.n`). The lapse probabilities used by the  bucket are the weighted average of the lapse probabilities of the individual contracts.  Using this average rather than the individual lapse probabilities does incur an approximation error.  However, in many applications this approximation error  will be dominated by the unavoidable inaccuaracy of individual lapse probability estimates. 

The type `Buckets` holds all buckets and some additional information.

###Fluctuations

The type `Fluct` handels stochastic fluctuations of mortality, lapse, and administration costs.  Fluctations are modeled via a factor that follows a geometric Brownian motion.  It is also possible to provide fluctuations manually or no fluctuations at all.  

###Cash-flows

Cashflows are handeled by the type `CFlow`.  They act on instances of `Buckets` and `Fluct` and provide a table with projection values for the most important quantities for each Monte Carlo scenario `mc`.

##Book 

The book is in an early project phase.  We plan to offer it to a scientific publisher for publication, once it is finished.  The intended audience are

* modeling actuaries
* academics
* insurance regulators with actuarial background

We assume that the reader is familiar with mathematics at a level of a typical undergraduate math degree.

-------------------------------------------------------------------------------

[![Build Status](https://travis-ci.org/mkriele/MCInsurance.jl.png)](https://travis-ci.org/mkriele/MCInsurance.jl)

[^1]:  While other applications are also intended,  the code may not be suitable for a production environment without further testing.

[^2]: Here lapse is considered a biometric event.
