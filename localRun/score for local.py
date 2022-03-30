# import json
import joblib
import numpy as np
import pandas as pd
from datetime import date
# from azureml.core.model import Model
from sklearn.metrics import roc_auc_score
from sklearn.metrics import confusion_matrix, accuracy_score
from sklearn import metrics

us_abbrev_to_state = {
    'AL':'Alabama',
    'AK': 'Alaska',
    "AZ":"Arizona",
    "AR":"Arkansas",
    "CA":"California",
    "CO":"Colorado",
    "CT":"Connecticut",
    "DE":"Delaware",
    "FL":"Florida",
    "GA":"Georgia",
    "HI":"Hawaii",
    "ID":"Idaho",
    "IL":"Illinois",
    "IN":"Indiana",
    "IA":"Iowa",
    "KS":"Kansas",
    "KY":"Kentucky",
    "LA":"Louisiana",
    "ME":"Maine",
    "MD":"Maryland",
    "MA":"Massachusetts",
    "MI":"Michigan",
    "MN":"Minnesota",
    "MS":"Mississippi",
    "MO":"Missouri",
    "MT":"Montana",
    "NE":"Nebraska",
    "NV":"Nevada",
    "NH":"New Hampshire",
    "NJ":"New Jersey",
    "NM":"New Mexico",
    "NY":"New York",
    "NC":"North Carolina",
    "ND":"North Dakota",
    "OH":"Ohio",
    "OK":"Oklahoma",
    "OR":"Oregon",
    "PA":"Pennsylvania",
    "RI":"Rhode Island",
    "SC":"South Carolina",
    "SD":"South Dakota",
    "TN":"Tennessee",
    "TX":"Texas",
    "UT":"Utah",
    "VT":"Vermont",
    "VA":"Virginia",
    "WA":"Washington",
    "WV":"West Virginia",
    "WI":"Wisconsin",
    "WY":"Wyoming",
    "DC":"District of Columbia",
    "AS":"American Samoa",
    "GU":"Guam",
    "MP":"Northern Mariana Islands",
    "PR":"Puerto Rico",
    "UM":"United States Minor Outlying Islands",
    "VI":"U.S. Virgin Islands"
}
    
# Called when a request is received
def run(raw_data):
    # pass raw_data as string
    global data, missing_imputer, rare_imputer, target_encoder, dsAppIds, data_fitting
    data = pd.DataFrame(raw_data.copy())
    model = joblib.load('../deploymentFiles/xgb_model.pkl')
    missing_imputer = joblib.load('../deploymentFiles/missing_imputer.pkl')
    rare_imputer = joblib.load('../deploymentFiles/rare_imputer.pkl')
    target_encoder = joblib.load('../deploymentFiles/target_encoder.pkl')
    dsAppIds = data['ApplicantID']
#     data_f = data
    data_fitting = pre_processing(data, missing_imputer, rare_imputer, target_encoder)
    predictions = model.predict(data_fitting)
    prob = model.predict_proba(data_fitting)
    score = prob[:, 0]*1000
    # Return the predictions as any JSON serializable format
    
    cols = [x.replace('diff', '') if x.endswith('diff') else x for x in data_fitting.columns]
    data = data[cols]
    data['Score'] = score
    data['Predicted'] = predictions
    data['ApplicantID'] = dsAppIds
      
    return data
#     return predictions.tolist(), prob.tolist(), score.tolist()

def pre_processing(in_data, missing_imputer, rare_imputer, target_encoder):
    data = in_data.copy()
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
    
    datediff_missing = {'PayDateMatchProjecteddiff': -2, 
                        'LastPaymentDatediff': 48,
                        'ProjectedPayDatediff': -13, 
                        'LastDateApplicationReceiveddiff': 20, 
                        'SFLastDateApplicationReceiveddiff': 145}
    missing_imputer.update(datediff_missing)
    for var in train_vars:
        if var not in ['Pre_Status', 'IPAddressOriginDomains']:
            data[var].fillna(missing_imputer[var], inplace = True)
    # for Pre_Status and IPAddressOriginDomains, mark missing as one category
    data['Pre_Status'] = np.where(data['Pre_Status'].isnull(), 'BrandNew', data['Pre_Status'])
    data['IPAddressOriginDomains'] = np.where(data['IPAddressOriginDomains'].isnull(), 'Missing', data['IPAddressOriginDomains'])
    
    # Transfer data type to prepare for target encoding 
    for var in ['CustomerDDACount1Year', 'CustomerDDACount6Months', 'NumberofMerchants30', 'NumberofCustomersonBankAccount', 'SFNumberofMerchants']:
        data[var] = data[var].astype(float)
    
    # rare imputation
    cols = ['NumberofMerchants30','Pre_Status','State_y','SFNumberofMerchants','Bank','Loanamount','Affiliate','CustomerDDACount1Year',
'ActiveAccount','NumberofCustomersonBankAccount','CustomerDDACount6Months','IPAddressOriginDomains']
    for col in cols:
        if col == 'Pre_Status':
            rare_imputation(data, col, rare_imputer, 'frequent')
        else:
            rare_imputation(data, col, rare_imputer, 'rare')

    # encode categorical
    for var in cols:
        data[var] = data[var].map(target_encoder[var])

    data = data[train_vars]
    return data

def p2f(x):
    if type(x) == str:
        return float(x.strip('%'))/100
    else:
        return x
    
def rare_imputation(data, variable, rare_imputer, which = 'rare'):    
    frequent_cat = rare_imputer[variable][0]
    # create new variables, with Rare labels imputed
    if which == 'frequent':
        # find the most frequent category
        mode_label = rare_imputer[variable][1]
        data[variable] = np.where(data[variable].isin(frequent_cat), data[variable], mode_label)
    else:
        data[variable] = np.where(data[variable].isin(frequent_cat), data[variable], 'rare')

########################################################################################
# LOAD DATA FROM FILE
########################################################################################



def monthly_income(dataset):
    if dataset['PeriodPaymentInfo'] == 'Hourly':
        return dataset['PeriodIncome']*8*5*52/12
    elif dataset['PeriodPaymentInfo'] == 'Daily':
        return dataset['PeriodIncome']*5*52/12
    elif dataset['PeriodPaymentInfo'] == 'Weekly':
        return dataset['PeriodIncome']*52/12
    elif dataset['PeriodPaymentInfo'] == 'Bi-weekly':
        return dataset['PeriodIncome']*26/12
    elif dataset['PeriodPaymentInfo'] == 'Semi-monthly':
        return dataset['PeriodIncome']*2
    elif dataset['PeriodPaymentInfo'] == 'Monthly':
        return dataset['PeriodIncome']
    elif dataset['PeriodPaymentInfo'] == 'Annual':
        return dataset['PeriodIncome']/12
    else:
        return 0

def  load_Data_From_csvs(customerDataFile, FTDataFile):
    # FTData
    FTdata = pd.read_csv(FTDataFile)
    
    # Customer Data
    custData = pd.read_csv(customerDataFile)
    #custData['SubID'] = np.where((custData['SubID'] == 'npdlref') | (custData['SubID'] == 'tlusaRef'), 'mpd', custData['SubID'])
    #custData['StaticPool'] = custData['TotalPaid']/custData['TotalLend']
    #custData['Pre_Status'].fillna('BrandNew', inplace = True)
    #custData = custData.sort_values('TWNResponseDte').drop_duplicates('ApplicantID',keep='last')
    custData = custData[custData['TWNResponse'].isnull() == False]
    
    data = pd.merge(FTdata, custData, left_on='ApplicationID', right_on='ApplicantID')
    # data = data[data['Cycled'] == 1]
    # data = data[data['AffiliateCat'] == 'Organic']
    # data = data[pd.to_datetime(data['TransactionDate']) >= '01/01/2020']
    # print(data.shape)
    # data.head()
    
    # Rename columns
    data.rename({'RiskScore':'RiskScore_y'}, axis='columns', inplace=True)
    # data.rename({'State':'State_y'}, axis='columns', inplace=True)
    
    # invert the dictionary
    data['State_y'] = data['State'].map(us_abbrev_to_state)
    
    #  Extract info and create columns from TWNResponse
    import ast
    #x = ast.literal_eval(custData['TWNResponse'][0])
    #x
    
    # Clean out data with invalid TWN Response
    data = data[data['TWNResponse'].astype(str).str.startswith('[')]
    
    
    new_list = []
    for twnresponse in data['TWNResponse']:
        if twnresponse[-1] != ']':
            print(twnresponse)
            indexes = [index for index, element in enumerate(twnresponse) if element == '{']
    #         print(indexes)
            print(int(indexes[-1]))
            end = int(indexes[-1]-1)
            twnresponse = twnresponse[:end]+']'
        new_list.append(twnresponse)    
    data['TWNResponse'] = new_list
    
    #         print(indexes)
    
    #for twnresponse in data['TWNResponse']:
        #if twnresponse[-1] != ']':
            #print(twnresponse)
    
    #for twnresponse in data['TWNResponse']:
        #if 'PaymentFrequency' not in twnresponse:
            #print(twnresponse)        
    
    
    position_title = []
    pay_frequency = []
    period_pay_info = []
    period_income = []
    active_cnt = []
    employer_num = []
    for twnresponse in data['TWNResponse']:
        cnt = 0
        num = 0
        active_date = []
        for j in ast.literal_eval(twnresponse)[:-2]:
            num += 1
            if j['EmploymentStatus'] == 'Active':
                cnt += 1
                active_date.append(j['CurrDateAsOf'])
        active_date.sort()
        
        if cnt == 0:
            position_title.append('N/A')
            pay_frequency.append('N/A')
            period_pay_info.append('N/A')
            period_income.append('0')
        elif 'PaymentFrequency' not in twnresponse:
            pay_frequency.append('N/A')
            if 'PeriodPaymentInfo' not in twnresponse:
                period_pay_info.append('N/A')
            if 'PeriodIncome' not in twnresponse:
                period_income.append('0')
    #     print(active_date)
    
        for m in ast.literal_eval(twnresponse)[:-2]:
            if m['EmploymentStatus'] == 'Active' and m['CurrDateAsOf'] == active_date[-1] and 'PaymentFrequency' in twnresponse and 'PeriodPaymentInfo' in twnresponse and 'PeriodIncome' in twnresponse:
    #             position_title.append(m['PositionTitle'])
                pay_frequency.append(m['PaymentFrequency'])
                period_pay_info.append(m['PeriodPaymentInfo'])
                period_income.append(m['PeriodIncome'])
                if len(active_date) >= 2 and active_date[-1] == active_date[-2]:
                    break
        active_cnt.append(cnt)
        employer_num.append(num)
    # print(employer_num)
    # print(position_title)
    # print(pay_frequency)
    # print(period_pay_info)
    # print(active_cnt)
    # print(len(employer_num))
    # print(len(position_title))
    # print(len(pay_frequency))
    # print(len(period_pay_info))
    # print(len(active_cnt))
    
    
    
    data['EmployerNumbers'] = employer_num
    data['ActiveAccount'] = active_cnt
    # data['PositionTitle'] = position_title
    data['PaymentFrequency'] = pay_frequency
    data['PeriodPaymentInfo'] = period_pay_info
    data['PeriodIncome'] = period_income
    
    # create a column of TWN monthly income
    data['PeriodIncome'] = pd.to_numeric(data['PeriodIncome'])
    data['MonthlyIncome'] = data.apply(monthly_income, axis=1)
    data['MonthlyIncome'] = round(data['MonthlyIncome'])
    #data.head()
    
    return data



#################################################################################
#                               RUN LOCAL                                       #
#################################################################################

customerDataFile = r'C:\Users\manuelc\OneDrive - The Strategic Group\Documents\Sprints\Sprint_12\DAP-241\PostCheck_TWN_ApplicantData_Sept20.csv'
FTDataFile = r'C:\Users\manuelc\OneDrive - The Strategic Group\Documents\Sprints\Sprint_12\DAP-241\FTdata_TWN_Model_IntegrationAnalysis_Sept20.csv'

raw_data = load_Data_From_csvs(customerDataFile, FTDataFile)
dataout = run(raw_data)

dataout.columns
dataout['Score'].isnull().mean()

json_vars = ['Bank', 'State_y', 'Age', 'Salary', 'Bankaccountlengthmonths', 
             'Monthsatresidence', 'MonthsOnJob', 'Loanamount', 'TimesAppliedAll', 
             'Pre_Status', 'Affiliate', 'Payment_ratio', 'FraudRiskScore', 
             'MonthlyIncome', 'EmployerNumbers', 'ActiveAccount', 'RiskScore_y', 
             'PayDateMatchProjected', 'NumberofMerchants30', 'FPDForABA', 
             'CustomerDDACount', 'PayDateMatchPercentage', 'SFNumberofOpenLoans', 
             'CustomerAddressCount', 'NumberofLoansPaidOff', 'SFNumberofMerchants', 
             'TotalNumberofLoansOriginated', 'TotalNumberofLoansDelinquent', 
             'CustomerDDACount1Year', 'TotalNumberofLoansOriginatedLastYear', 
             'SFNumberofLoansPastDue', 'LastPaymentDate', 'NumberofCustomersonBankAccount', 
             'PayDateMatchCount', 'TotalNumberofLoansDelinquentLastYear', 
             'SFNumberofNewLoansOriginatedLastYear', 'SFNumberofNewLoansOriginated', 
             'CustomerDDACount6Months', 'SFTotalOSBalance', 'NumberofApplicationsAllTime', 
             'NumberofApplications', 'TotalOSBalance', 'LastDateApplicationReceived', 
             'TotalAmountDelinquent', 'TotalAmountDelinquentLastYear', 
             'NumberofMerchantsAllTime', 'NumberofApplications30', 'ProjectedPayDate', 
             'SFLastDateApplicationReceived', 'IPAddressOriginDomains', 'LastPaymentAmount', 
             'FPDForABACount', 'NumberofApplications90', 'NumberofLoansPastDue', 
             'PayFrequencyMatchPercentage', 'SFNumberofLoansPaidOffLastYear']

# create json column
import datetime
dataout['TimesAppliedAll'] = 1
jsons = pd.DataFrame()
for idx, row in dataout[json_vars].iterrows():
    jsonstr = '{'
    for x in row.index:
        value = row[x]
        if isinstance(value, datetime.date):
            value = '"'+str(value.strftime("%m/%d/%Y, %H:%M:%S" "%p"))+'"' 
        elif isinstance(value, str):
            value = '"' + str(value) + '"'
        else:
            value = str(value)
        key = '"' + x + '":[' + value + ']'
        jsonstr = jsonstr + key
        jsonstr = jsonstr + ('}' if row.index[-1] == x else ',')
    jsonrow = pd.DataFrame({'JSON': jsonstr}, index=[idx])
    jsons = pd.concat([jsons, jsonrow])

dataout = pd.merge(dataout, jsons, left_index=True, right_index=True)
dataout = dataout[['ApplicantID', 'Score', 'Predicted', 'JSON'] + json_vars]

########################################################################################
# JSON RUN
 
json1 = {"Bank":["KERN FEDERAL CREDIT UNION"],"State_y":["California"],"Age":[53],"Salary":[6000],"Bankaccountlengthmonths":[36],"Monthsatresidence":[48],"MonthsOnJob":[60],"Loanamount":[500],"TimesAppliedAll":[1],"Pre_Status":["BrandNew"],"Affiliate":["LM40"],"Payment_ratio":[0.050000],"FraudRiskScore":[99],"MonthlyIncome":[4068],"EmployerNumbers":[1],"ActiveAccount":[1],"RiskScore_y":[755],"PayDateMatchProjected":["11/20/2018 12:00:00 AM"],"NumberofMerchants30":[0.0],"FPDForABA":[5],"CustomerDDACount":[3],"PayDateMatchPercentage":["0%"],"SFNumberofOpenLoans":[0],"CustomerAddressCount":[3],"NumberofLoansPaidOff":[6],"SFNumberofMerchants":[0.0],"TotalNumberofLoansOriginated":[7],"TotalNumberofLoansDelinquent":[1],"CustomerDDACount1Year":[0.0],"TotalNumberofLoansOriginatedLastYear":[0],"SFNumberofLoansPastDue":[0],"LastPaymentDate":["2/5/2015 12:00:00 AM"],"NumberofCustomersonBankAccount":[1.0],"PayDateMatchCount":[1],"TotalNumberofLoansDelinquentLastYear":[0],"SFNumberofNewLoansOriginatedLastYear":[0],"SFNumberofNewLoansOriginated":[0],"CustomerDDACount6Months":[0.0],"SFTotalOSBalance":[0],"NumberofApplicationsAllTime":[15],"NumberofApplications":[5],"TotalOSBalance":[0],"LastDateApplicationReceived":["7/7/2017 1:01:02 PM"],"TotalAmountDelinquent":[0],"TotalAmountDelinquentLastYear":[0],"NumberofMerchantsAllTime":[1],"NumberofApplications30":[0],"ProjectedPayDate":["11/23/2018 12:00:00 AM"],"SFLastDateApplicationReceived":["8/5/2016 5:15:05 PM"],"IPAddressOriginDomains":["rr.com[7/7/2017,7/7/2017];twcable.com[7/4/2017,8/11/2014];brighthouse.com[6/27/2014,6/27/2014]"],"LastPaymentAmount":[315],"FPDForABACount":[44],"NumberofApplications90":[0],"NumberofLoansPastDue":[1],"PayFrequencyMatchPercentage":["93%"],"SFNumberofLoansPaidOffLastYear":[0]}
json1['ApplicantID'] = 1
jsonout = run(json1)

dataout.to_csv(r'C:\Users\manuelc\OneDrive - The Strategic Group\Documents\Sprints\Sprint_12\DAP-241\MPD_PostCheck_TWN_IntegrationAnalysis.csv')

#appIDs = []
#data[data['ApplicationID'].isin(appIDs)]