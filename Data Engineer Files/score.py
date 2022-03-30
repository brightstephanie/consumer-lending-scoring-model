import json
import joblib
import numpy as np
import pandas as pd
from azureml.core.model import Model
from datetime  import date

# Called when the service is loaded
def init():
    global model, missing_imputer, rare_imputer, target_encoder
    # Get the path to the registered model file and load it
    model_path = Model.get_model_path('mpd_TWN_FPD_v1_0_xgb_model')
    missing_path = Model.get_model_path('mpd_TWN_FPD_v1_0_mis_imput')
    rare_path = Model.get_model_path('mpd_TWN_FPD_v1_0_rar_imput')
    target_path = Model.get_model_path('mpd_TWN_FPD_v1_0_tar_encod')
    model = joblib.load(model_path)
    missing_imputer = joblib.load(missing_path)
    rare_imputer = joblib.load(rare_path)
    target_encoder = joblib.load(target_path)

# Called when a request is received
def run(raw_data):
    global data
    data = json.loads(raw_data)
    data = pd.DataFrame(data)
    data = pre_processing(data, missing_imputer, rare_imputer, target_encoder)
    # Get a prediction from the model
    predictions = model.predict(data)
    prob = model.predict_proba(data)
    score = prob[:,0]*1000
    # Return the predictions as any JSON serializable format
    return prob.tolist(), score.tolist()
	
	
def pre_processing(data, missing_imputer, rare_imputer, target_encoder):
    data['Bank'] = data['Bank'].str.upper() 

    list_i = []
    for i in data['Bank']:
        if type(i) == str:
            if 'CHAS' in i:
                i = 'CHASE'
            elif 'BANK OF AMERICA' in i or 'BANKOFAMERICA' in i or 'BANKOF AMERICA' in i:
                i = 'BANK OF AMERICA'
            elif 'WELLS FARGO' in i:
                i = 'WELLS FARGO'
            elif 'PNC' in i:
                i = 'PNC'
            elif 'WACHOVIA' in i:
                i = 'WACHOVIA'
            elif 'WOODFOREST' in i:
                i = 'WOODFOREST NATIONAL BANK'
            elif 'CITI' in i:
                i = 'CITI'
        else:
            i = i
        list_i.append(i)
    data['Bank'] = list_i
	
    # Transfer percentage variables
    cat_percent = ['PayDateMatchPercentage','PayFrequencyMatchPercentage']
    for var in cat_percent:
        row_list = []
        for i in data[var]:
            row_list.append(p2f(i))
        data[var] = row_list
        
    #     Process date variables
    datetime_var = ['PayDateMatchProjected', 'ProjectedPayDate', 'SFLastDateApplicationReceived','LastDateApplicationReceived', 'LastPaymentDate']
    for var in datetime_var:
        data[var + 'diff'] = pd.to_datetime(str(date.today()), format='%Y-%m-%d') - pd.to_datetime(data[var])
        data[var + 'diff'] = data[var + 'diff']/np.timedelta64(1,'D')
        
    # Treat missing value
    # for Pre_Status, mark missing as one category
    data['Pre_Status'] = np.where(data['Pre_Status'].isnull(), 'BrandNew', data['Pre_Status'])
    
    
    # rare imputation
    cols = ['NumberofMerchants30','Pre_Status','State_y','SFNumberofMerchants','Bank','Loanamount','Affiliate','CustomerDDACount1Year',
'ActiveAccount','NumberofCustomersonBankAccount','CustomerDDACount6Months','IPAddressOriginDomains']
    for col in cols:
        if col == 'Pre_Status':
            rare_imputation(col, rare_imputer, 'frequent')
        else:
            rare_imputation(col, rare_imputer, 'rare')

    # encode categorical
    for var in cols:
        data[var] = data[var].map(target_encoder[var])

    train_vars = ['RiskScore_y',
                 'Payment_ratio',
                 'PayDateMatchProjecteddiff',
                 'SFNumberofOpenLoans',
                 'FPDForABA',
                 'EmployerNumbers',
                 'Bankaccountlengthmonths',
                 'SFNumberofLoansPastDue',
                 'NumberofLoansPaidOff',
                 'PayDateMatchPercentage',
                 'CustomerDDACount',
                 'TotalNumberofLoansDelinquent',
                 'Pre_Status',
                 'Bank',
                 'State_y',
                 'MonthsOnJob',
                 'CustomerDDACount1Year',
                 'Age',
                 'Affiliate',
                 'TotalNumberofLoansOriginated',
                 'Loanamount',
                 'SFNumberofMerchants',
                 'CustomerAddressCount',
                 'TotalNumberofLoansOriginatedLastYear',
                 'ActiveAccount',
                 'NumberofCustomersonBankAccount',
                 'LastPaymentDatediff',
                 'MonthlyIncome',
                 'SFNumberofNewLoansOriginatedLastYear',
                 'FraudRiskScore',
                 'SFNumberofNewLoansOriginated',
                 'ProjectedPayDatediff',
                 'NumberofApplications',
                 'TotalNumberofLoansDelinquentLastYear',
                 'PayFrequencyMatchPercentage',
                 'PayDateMatchCount',
                 'NumberofApplicationsAllTime',
                 'TotalOSBalance',
                 'LastDateApplicationReceiveddiff',
                 'NumberofMerchantsAllTime',
                 'CustomerDDACount6Months',
                 'NumberofLoansPastDue',
                 'SFTotalOSBalance',
                 'SFNumberofLoansPaidOffLastYear',
                 'TotalAmountDelinquentLastYear',
                 'NumberofApplications30',
                 'TotalAmountDelinquent',
                 'NumberofApplications90',
                 'Monthsatresidence',
                 'IPAddressOriginDomains',
                 'LastPaymentAmount',
                 'SFLastDateApplicationReceiveddiff',
                 'FPDForABACount',
                 'Salary',
                 'NumberofMerchants30']
    data = data[train_vars]
    return data

def p2f(x):
    if type(x) == str:
        return float(x.strip('%'))/100
    else:
        return x
    
def rare_imputation(variable, rare_imputer, which = 'rare'):    
    frequent_cat = rare_imputer[variable][0]
    # create new variables, with Rare labels imputed
    if which == 'frequent':
        # find the most frequent category
        mode_label = rare_imputer[variable][1]
        data[variable] = np.where(data[variable].isin(frequent_cat), data[variable], mode_label)
    else:
        data[variable] = np.where(data[variable].isin(frequent_cat), data[variable], 'rare')