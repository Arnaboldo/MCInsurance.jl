export AssetOther, notaxcredit!

##------------------------------------------------------------------------------
type AssetOther
  model_new_tax_credit::Bool   ## model tax credit mechanism for future losses
                               ##   usage of init. tax credit is always modeled
  tax_credit_init::Float64     ## initial tax credit
end


