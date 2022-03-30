from azureml.core.model import Model
from azureml.core import Workspace


workspace = "prod_ml_workspace"
subscription_id = "19277e90-a783-401b-925e-064aba7220f9"
resource_group = "prod_ScoringBlackBox_Linux"
model_name = "mpd_TWN_FPD_v1_0_xgb_model"
modelFileName = "./deploymentFiles/xgb_model.pkl"


ws = Workspace.get(name=workspace,
               subscription_id=subscription_id,
               resource_group=resource_group)

print("Found workspace {} at location {}".format(ws.name, ws.location))

model = Model.register(model_path=modelFileName,
                        model_name=model_name,
                        tags={"data": "MPD", "model": "TWN FPD v1.0"},
                        description="TWN FPD Model for MPD v1.0",
                        workspace=ws)