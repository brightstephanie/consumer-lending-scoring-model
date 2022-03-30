from azureml.core.environment import Environment
from azureml.core import Workspace
from azureml.core.model import InferenceConfig, Model
from azureml.core.webservice import LocalWebservice
from azureml.core.webservice import AciWebservice

# Create inference configuration based on the environment definition and the entry script
myenv = Environment.from_conda_specification(name="env", file_path="./Data Enginier Files/service_files/env.yml")
inference_config = InferenceConfig(entry_script="./Data Enginier Files/score.py", environment=myenv)
# Create a local deployment, using port 8890 for the web service endpoint

workspace = "prod_ml_workspace"
subscription_id = "19277e90-a783-401b-925e-064aba7220f9"
resource_group = "prod_ScoringBlackBox_Linux"

ws = Workspace.get(name=workspace,
               subscription_id=subscription_id,
               resource_group=resource_group)

mpd_xgb =Model(ws, "mpd_TWN_FPD_v1_0_xgb_model")
mpd_target =Model(ws, "mpd_TWN_FPD_v1_0_tar_encod")
mpd_rare =Model(ws, "mpd_TWN_FPD_v1_0_rar_imput")
mpd_missing =Model(ws, "mpd_TWN_FPD_v1_0_mis_imput")


package = Model.package(ws, [mpd_xgb,mpd_target,mpd_rare,mpd_missing], inference_config)
package.wait_for_creation(show_output=True)
# Display the package location/ACR path
 