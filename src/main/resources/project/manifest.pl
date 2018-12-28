@files = (
    ['//property[propertyName="ECSCM::Vault::Cfg"]/value', 'VaultCfg.pm'],
    ['//property[propertyName="ECSCM::Vault::Driver"]/value', 'VaultDriver.pm'],
    ['//property[propertyName="sentry"]/value', 'VaultSentryForm.xml'],
    ['//property[propertyName="checkout"]/value', 'VaultCheckoutForm.xml'],
    ['//property[propertyName="createConfig"]/value', 'VaultCreateConfigForm.xml'],
    ['//property[propertyName="trigger"]/value', 'VaultTriggerForm.xml'],
    ['//property[propertyName="editConfig"]/value', 'VaultEditConfigForm.xml'],
    ['//property[propertyName="preflight"]/value', 'VaultPreflightForm.xml'],
    ['//property[propertyName="ec_setup"]/value', 'ec_setup.pl'],
    ['//procedure[procedureName="Preflight"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'VaultPreflightForm.xml'],
    ['//procedure[procedureName="CheckoutCode"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'VaultCheckoutForm.xml'],    
);
