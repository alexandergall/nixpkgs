lib:

with lib;
with builtins;

rec {
  ## 
  scanVendor = devices: vendor:
    let
      models = attrNames (filterAttrs (n: v: v.enable)
                                      devices."${vendor}");
    in
    if models == [] then
      null
    else
      if length models == 1 then
        { vendor = "${vendor}"; model = "${elemAt models 0}"; }
      else
        throw (''Multiple active models for vendor "${vendor}" '' +
               ''(chose one): '' + concatStringsSep ", " models);
               
  findActiveModel = devices: fatal:
    let
      vendors = remove null (map (scanVendor devices) (attrNames devices));
    in
    if length vendors == 1 then
      let
        model = elemAt vendors 0;
      in
        {
          modelSet = devices."${model.vendor}"."${model.model}";
          vendorName = model.vendor;
          modelName = model.model;
        }
    else
      if fatal then
        if vendors == [] then
          throw ''No active vendor/model found in services.snabb.devices''
        else
          throw (''Multiple active vendor/modules (chose one): '' +
                 concatStringsSep ", "
                   (map (s: "${s.vendor}/${s.model}") vendors))
      else
        null;
}
