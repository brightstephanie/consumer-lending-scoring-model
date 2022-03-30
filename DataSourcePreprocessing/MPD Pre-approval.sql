-- ============================================================
-- Author:		Ying Cheng, Fangyu Su, Minfei
-- Create date: --/--/----
-- Latest Update date: 12/30/2019
-- Description:	Query about traffic and cost of the applicants
--              (including affiliate and organic)
-- ============================================================

DECLARE @StartDate SMALLDATETIME
DECLARE @EndDate SMALLDATETIME

SET @StartDate = '01/01/2021' --CONVERT(DATE,DATEADD(day,-108 -(DATEPART(weekday, GETDATE()) + @@DATEFIRST - 2)  % 7, GETDATE()))
SET @EndDate = getdate() --CONVERT(DATE,DATEADD(day, -1 -(DATEPART(weekday, GETDATE()) + @@DATEFIRST - 2) % 7, GETDATE()))
SET DATEFIRST 1

-- Declare cost variables
DECLARE @IdologyCost DECIMAL(10,2);
DECLARE @GverifyCost DECIMAL(10,2);
DECLARE @Data247 DECIMAL(10,3); -- Data 24/7 Cost is 0.005, requries 3 digit precision
DECLARE @LoanPerformanceCost DECIMAL(10,2);
DECLARE @IDVCost DECIMAL(10,2);
DECLARE @MicrobiltCost DECIMAL(10,2);
DECLARE @ChexAdvisorCost DECIMAL(10,2);
DECLARE @MlaCost DECIMAL(10,2)
DECLARE @LoanPerformanceString VARCHAR(17);
DECLARE @IdLogicString VARCHAR(5);
DECLARE @ChexAdvisorString VARCHAR(13);
DECLARE @TUAttributesCost DECIMAL(10,2);
DECLARE @TUAttributesString VARCHAR(18);
DECLARE @TWNPrice1 DECIMAL(10,2);
DECLARE @TWNPrice2 DECIMAL(10,2);


-- Set values to all variables
SET @IdologyCost = 0.07
SET @MicrobiltCost = 0.10
SET @GverifyCost = 0.25
SET @Data247 = 0.005
SELECT @ChexAdvisorCost = ChexAdvisor, @IDVCost = IDLogic, @LoanPerformanceCost = RiskCompliance FROM Mypayday.dbo.CostPerService
SET @TUAttributesCost = 0.70 -- This is the 3rd level cost for FT Store 30
SET @MlaCost = 0.06
SET @LoanPerformanceString = '<LoanPerformance>';
SET @IdLogicString = '<IDV>';
SET @ChexAdvisorString = '<ChexAdvisor>';
SET @TUAttributesString = '<Service Name="TraditionalCreditAttributes">';
SET @TWNPrice1 = 6.00; -- Effective price before 12/1
-- SET @TWNPrice2 = 5.10; -- Effective price starting 12/1
SET @TWNPrice2 = 3.80;

;WITH AffTracker AS
(
    SELECT distinct
        BAL.BuyappslogID as BuyappslogID
        ,APP.ID AS ApplicantID 
        ,CONVERT(DATE, BAL.DATE) AS ReceivedDte 
        ,MONTH(BAL.DATE) AS ReceivedMonth
        ,Year(BAL.Date) as ReceivedYear
        ,DATENAME(week, BAL.DATE) AS WeekNum
        ,DATEPART(HH,BAL.Date) as ReceivedHour
        ,DATENAME(dw,BAL.Date) as 'DayName'
        --,DATEPART(dw,BAL.Date) as DayNum1
        ,Case when (DATEPART(dw,BAL.Date) between 1 and 5) and DATEPART(HH,BAL.Date) between 9 and 23 then 'Hour'
            when (DATEPART(dw,BAL.Date) between 6 and 7) and DATEPART(HH,BAL.Date) between 9 and 18 then 'Hour'
            ELSE 'Off-Hour' END AS WorkingHour
		,CASE WHEN BAL.[status] = 'Accepted' THEN 1 ELSE 0 END AS IfAccepted
		,CASE WHEN APP.Type = 'Approved' THEN 1 ELSE 0 END AS IfFunded
        ,APP.Type AS ApplicantType
        ,CONVERT(DATE, BAL.Date) AS BoughtDte
        ,BAL.Status AS BuyStatus 
        ,BAL.ViewContractDate
        ,BAL.SignatureDate
        ,TR.LinkOpenDate
        ,CASE
            WHEN AFF.TrafficSource = 'Organic' THEN 'Organic' ELSE AFF.Name END AS Affiliate
        ,CASE WHEN AFF.TrafficSource = 'Organic' THEN 'Organic' 
			WHEN AFF.Name IN ('IT Media','ITMedia12','IT Media25','ITMediaInternal','IT20','ITMedia40','ITMedia7','ITMedia3rd','ITMedia50', 'IT Media CPF') THEN 'IT Media'
			WHEN AFF.Name IN ('LeadGroup7','LeadGroup','LeadGroup25','LeadGroup40') THEN 'Lead Group'
			WHEN AFF.Name IN ('Leads Market','LM12', 'LM20','LM25','LM40','LMSeven') THEN 'Leads Market'
			WHEN AFF.Name IN ('partnerweekly','partnerweekly25','PartnerWeekly40') THEN 'PartnerWeekly'
			WHEN AFF.Name IN ('StoreFront20','StoreFront26','StoreFront40','SF12', 'StoreFront CPF') THEN 'StoreFront'
			WHEN AFF.NAME IN ('LeadToro','LeadToro25') THEN 'LeadToro'
			WHEN AFF.NAME = 'Paul' THEN 'Paul'
			WHEN AFF.NAME = 'RoundSky35' THEN 'RoundSky'
			WHEN AFF.NAME IN ('ZeroParallel15', 'ZeroParallel40')  THEN 'ZeroParallel'
			WHEN AFF.NAME IN ('GulfCoast25', 'GulfCoast12') THEN 'GulfCoast'
			--WHEN AFF.NAME = 'LG25' THEN 'LG'
			WHEN AFF.NAME = 'PingYo25' THEN 'PingYo'
			WHEN AFF.NAME = 'YaSolutions20' THEN 'YaSolutions'
            WHEN AFF.NAME = 'MediaLoud25' THEN 'MediaLoud'
            WHEN AFF.NAME = 'Intimate30' THEN 'Intimate'
			ELSE 'Other Affiliates' END AS AggregatedAFF
        ,CASE
            WHEN APP.AffID in ('x','mpd', 'National Payday') or payday.affID in ('x','mpd') THEN 'Organic' ELSE 'Leads' END AS AffiliateCat
        ,CASE 
            WHEN AFF.Name ='MoneyMutual' AND CHARINDEX('-',APP.AffID)>0 THEN LEFT(APP.AffID,CHARINDEX('-',APP.AffID)-1) 
            WHEN AFF.Name ='MoneyMutual' AND CHARINDEX('_',APP.AffID)>0 THEN LEFT(APP.AffID,CHARINDEX('_',APP.AffID)-1)
            ELSE APP.AffID   END AS SubID
        ,payday.type as paydaytype
        ,payday.ID as PaydayID
        ,Payday.Social as PaydaySocial
        ,DATEDIFF(minute,PassModelTime.Date,UWProcessingTime.Date ) AS ResponseTime
        ,DATEDIFF(second,PassModelTime.Date,UWProcessingTime.Date ) AS ResponseTime_second
        ,PassModelTime.Date as PassModelTime
        ,UWProcessingTime.Date as FCMTime
        --,CASE WHEN CNR.Date IS NOT NULL THEN 'YES' ELSE 'NO' END AS IFCNR
        ,CASE WHEN APP.StageID = '18' THEN 1 ELSE 0 END AS IsCNR
        ,app.directdeposit
        ,states.Name
        ,states.abbr
        -- , case when DATEDIFF(DAY, CONVERT(DATE,APP.DOB), CONVERT(DATE, APP.DTE))/365>1000 then
        -- DATEDIFF(DAY, CONVERT(DATE,APP.DOB), CONVERT(DATE, APP.DTE))/365-1000 else DATEDIFF(DAY, CONVERT(DATE,APP.DOB), CONVERT(DATE, APP.DTE))/365 end AS Age
		,CONVERT(INT, (CHARINDEX('Y', APP.Yearsonjob) - 3))*12 + CONVERT(INT, (CHARINDEX('M', APP.Yearsonjob) - 3)) AS MonthsOnJob
		,RIGHT(RTRIM(APP.email), LEN(APP.email)-CHARINDEX('@', APP.email)) AS Email_Domain
        ,app.Bankaccountlengthmonths
        ,app.Monthsatresidence
        ,app.Residencetype
        ,APP.Bank
        ,APP.Routingnum
        ,APP.Salary
        ,APP.[State]
        ,APP.IsTWNVerified
		-- ,CONVERT(DECIMAL(10,4),CONVERT(DECIMAL(10,2), APP.Loanamount)*0.3*2/(CONVERT(DECIMAL(18,2),REPLACE(APP.Salary,'$',''))*1.0)) AS Payment_ratio
		,ApplyBefore.TimesAppliedAll
        ,PreviousApp.Pre_Status

        ,CRLHome.[Status] as CarrierHomeStatus
        ,CRLCell.[Status] as CarrierCellStatus
        ,IDL.[Status] as IDologyStatus
		,CRL.Response_XML.value('(response/results/result/carrier_name)[1]', 'VARCHAR(20)') AS CarrierName
		,IDL.FraudRiskScore
        ,GVC.ResponseCode
        ,MT_FT.Decision AS FT_Decision
        ,MT_MLA.Decision AS MLA_Decision
        ,FTR.FactorTrustResponseID
        ,FTR.Response
        ,FTR.riskscore
		,CASE WHEN MT.Model= 'RandomForest' THEN 'Store 12-RF'
			WHEN FT.StoreID IS NULL and mt.storeID is not null and mt.storeid = 8 THEN 'Store 08'
			WHEN FT.StoreID IS NULL and mt.storeID is not null and mt.storeid = 13 THEN 'Store 13'
			WHEN FT.StoreID IS NULL and MT.StoreID is null and FTR.StoreID=14 THEN 'Store 14'
			WHEN FT.StoreID IS NULL and MT.StoreID is null and FTR.StoreID= 30 THEN 'Store 30'
			WHEN FT.StoreID IS NULL and mt.storeID is not null and mt.storeid = 30  THEN 'Store 30'
			WHEN FT.StoreID= 6 THEN 'Store 06'
			WHEN FT.StoreID= 7 THEN 'Store 07'
			WHEN FT.StoreID= 8 THEN 'Store 08'
			WHEN FT.StoreID= 9 THEN 'Store 09'
			WHEN FT.StoreID= 10 THEN 'Store 10'
			WHEN FT.StoreID= 11 THEN 'Store 11'
			WHEN FT.StoreID IS NULL and mt.storeID is not null and mt.storeid = 14  THEN 'Store 14'
			ELSE 'Other' END AS StoreID
        ,FTR0030.riskscore as NewFT_Score
		,FTR0030.Response_XML.value('(ApplicationResponse/LoanPerformance/NumberofLoansPaidOff)[1]', 'VARCHAR(10)') AS PaidOffLoans_NewFT
		,FTR.Response_XML.value('(ApplicationResponse/ApplicationInfo/LoanPerformance/NumberofLoansPaidOff)[1]', 'VARCHAR(10)') AS PaidOffLoans
		,CASE WHEN CP.CredictCard > 0 THEN 'Y' ELSE 'N' END AS CreditCardProvided
        ,CASE WHEN CHARINDEX('LoanPerformance',FTR.Response) > 0 THEN 1 ELSE 0 END as LoanPerformance
        ,CASE WHEN CHARINDEX('AddressisCurrent',FTR.Response) > 0 THEN 1 ELSE 0 END AS IDLogic
        ,CASE WHEN CHARINDEX('ChexAdvisor',FTR.Response) > 0 THEN 1 ELSE 0 END AS ChexAdvisor
        ,CASE WHEN FTMLA.STOREID='0020' THEN 1 ELSE 0 END AS MLA
		,TWN.Response AS TWNResponse
        
        ,ISNULL(AFF.LeadPrice,0.00) AS leadprice
        --,app.Loanamount as loanamount1
        ,ISNULL(CONVERT(DECIMAL(10,2),APP.Loanamount),0) AS Loanamount 
        ,Higher.[OriginalAmount]
        ,Higher.[HigherAmountSelected]
        ,Higher.[MaxHigherLoanAmount]
        ,CASE WHEN HIGHER.[OriginalAmount] IS NULL OR Higher.HigherAmountSelected IS NULL THEN 'NOT Offer'
            WHEN HIGHER.[OriginalAmount] IS NOT NULL AND HIGHER.[OriginalAmount]>=ISNULL(REPLACE(APP.Loanamount,'o','0'),0) THEN 'NOT UPSELL'
            ELSE 'UPSELL' END AS SellType
        ,APP.[AutomaticLoanProcessSuccessful]
        ,APP.[IsAutomaticLoanApproved]
        ,C.FailureReason
        ,CASE WHEN APP.[AutomaticLoanProcessSuccessful] = 0 AND APP.Type = 'Approved' THEN 'Manual-Approved'
            WHEN APP.[AutomaticLoanProcessSuccessful] = 1 AND APP.[IsAutomaticLoanApproved] = 0 AND APP.Type = 'Approved' THEN 'Semi-Auto-Approved'
            WHEN APP.[AutomaticLoanProcessSuccessful] = 1 AND APP.[IsAutomaticLoanApproved] = 1 AND APP.Type = 'Approved' THEN 'Auto-Approved'
            ELSE APP.TYPE END Type2

        ,LRL.LoanAmount as RenewalLoanAmount

        --,case when SMT.model = 'BayesianNetwork' then 1 else 0 end as EnterBayesian,
        --case when SMT.model = 'BayesianNetwork' and SMT.decision = 'Approve' then 1 else 0 end as PassBayesian,
        -- ,CASE WHEN BAL.Status = 'accepted' THEN ISNULL(AFF.LeadPrice,0.00) ELSE 0 END as Leadcost
        ,CASE 
            WHEN BAL.[Status] = 'Accepted' AND APP.Type = 'Rejected' THEN
                'Manual: ' + RRN.Note		
            WHEN BAL.[Status] = 'Accepted' AND APP.Type <> 'Rejected' THEN
                ''
            WHEN BAL.[Status] = 'Rejected' THEN
                LRR.AutoRejectionReason
            ELSE
                'UNKNOWN CASE'
        END AS RejectionReason

        --Cost query
        ,case when CRLHome.[Status] is not null then  @Data247 else 0  end as CarrierHomeCost
        ,case when CRLCell.[Status] is not null then  @Data247 else 0  end as CarrierCellCost
        ,CASE WHEN GVC.ResponseCode IS NOT NULL THEN @GverifyCost ELSE 0 END as gVerifyCost
        ,case when IDL.[Status] is not null then @IdologyCost else 0 end as IDologyCost
        ,CASE WHEN MB.[OpenTransactLogId] IS NOT NULL THEN @MicrobiltCost ELSE 0.00 END AS MicrobiltCost
		,CASE WHEN CHARINDEX(@LoanPerformanceString,FTR.Response) > 0 THEN @LoanPerformanceCost ELSE 0 END LoanPerformanceCost
		,CASE WHEN CHARINDEX(@IdLogicString,FTR.Response) > 0 THEN @IDVCost ELSE 0 END IdLogicCost
		,CASE WHEN CHARINDEX(@ChexAdvisorString,FTR.Response) > 0 THEN @ChexAdvisorCost ELSE 0 END ChexAdvisorCost
		,CASE WHEN CHARINDEX(@TUAttributesString, FTR.Response) > 0 THEN @TUAttributesCost ELSE 0 END TUAttributesCost
		,CASE WHEN FTMLA.StoreID IS NOT NULL THEN @MlaCost ELSE 0 END AS MlaCost
		,COALESCE(TWNL.TWNCost + TWNA.TWNCost,0) AS TWNCost
		,COALESCE(TWNL.TWNInquiries + TWNA.TWNInquiries,0) AS TWNInquiries
		-- If the lead record is not associated to an application file, is because it is a lead renewal
		,CASE WHEN AFF.TrafficSource <> 'Organic' AND AFF.Name NOT IN ('StoreFront CPF', 'IT Media CPF', 'ZeroParallel CPF', 'Paul') AND BAL.Status = 'Accepted' THEN AFF.leadprice 
            WHEN AFF.Name IN ('StoreFront CPF', 'IT Media CPF', 'ZeroParallel CPF') AND BAL.Status = 'Accepted' AND APP.Type = 'Approved' AND APP.ID IS NOT NULL THEN 0.25*ISNULL(CONVERT(DECIMAL(10,2),APP.Loanamount),0) 
            WHEN AFF.Name  = 'Paul' AND BAL.Status = 'Accepted' AND APP.Type = 'Approved' AND APP.ID IS NOT NULL THEN 75
            WHEN AFF.Name = 'Leads Market CPF' AND APP.Type = 'Accepted' AND APP.ID IS NOT NULL THEN 11
            ELSE 0 END AS NewLoanLeadCost
		,CASE WHEN AFF.TrafficSource <> 'Organic' AND BAL.[status] = 'Accepted' AND APP.ID IS NULL THEN AFF.LeadPrice ELSE 0 END AS RenewalLeadCost
		-- If the lead is not mapped to an applicant record and is accepted, it means it was processed as renewal or loan increase (existing customer)
		,CASE WHEN COALESCE(APP.ID,0) = 0 AND BAL.[status] = 'Accepted' AND APP.ID IS NULL THEN 1 ELSE 0 END AS ExistingCustomer
        --Payment query
        ,case when FBPayment.TotalPaid=0 and DATEDIFF(DAY,APP.DateDue,GETDATE()) > 7 then 1 else 0 end as Defaulted
		,CASE WHEN PA.Returned = 'Y' and PA.ReturnCode not in ('R01','R09','R99') THEN 1 ELSE 0 END as 'FPF'
		,CASE WHEN FirstPay.ID IS NULL AND DATEDIFF(DAY,APP.DateDue,GETDATE()) > 7 THEN 1
			WHEN FirstPay.ID IS NOT NULL AND DATEDIFF(DAY,APP.DateDue,FirstPay.Dte) > 7 THEN 1
			ELSE 0 END AS 'FPD'
		,CASE WHEN FBPayment.TotalPaymentTime = 1 AND FBPayment.RenewTimes = 0 AND (FBPayment.NewLoanAmount - FBPayment.PrincipalPaid) > 0 and  DATEDIFF(DAY,payday.Datedue,GETDATE()) > 7 THEN 1 ELSE 0 END AS OPD -- One Payment Default 
		,case when DATEDIFF(DAY, APP.DateDue, GETDATE()) > 7 then 1 else 0 end as 'Cycled'
		,FBPayment.TotalPaymentTime
		,FBPayment.RenewTimes
		,FBPayment.NewLoanAmount
		,FBPayment.Paidint
		,FBPayment.PrincipalPaid
		,FBPayment.TotalLend
		,FBPayment.TotalPaid
		,FBPayment.WOEntries
		,FBPayment.WrittenOffAmount
		,RES1.XmlNod.value('(./data[@name="income_monthly"])[1]','VARCHAR(100)') AS monthlyIncome_BAL
	    ,RES1.XmlNod.value('(./data[@name="bank_name"])[1]','VARCHAR(100)') AS bankName_BAL
	    ,RES1.XmlNod.value('(./data[@name="home_state"])[1]','VARCHAR(100)') AS state_BAL
	    ,RES1.XmlNod.value('(./data[@name="email_primary"])[1]','VARCHAR(100)') AS emailAddress_BAL
	    ,RES1.XmlNod.value('(./data[@name="date_dob_m"])[1]','VARCHAR(100)') + '/' + RES1.XmlNod.value('(./data[@name="date_dob_d"])[1]','VARCHAR(100)')  + '/' + RES1.XmlNod.value('(./data[@name="date_dob_y"])[1]','VARCHAR(100)') AS dob_BAL
	    ,RES1.XmlNod.value('(./data[@name="bank_length_months"])[1]','VARCHAR(100)') AS bankAccountMonths_BAL
	    ,RES1.XmlNod.value('(./data[@name="residence_length_months"])[1]','VARCHAR(100)') AS monthsAtResidence_BAL
	    ,RES1.XmlNod.value('(./data[@name="residence_type"])[1]','VARCHAR(100)') AS residenceType_BAL
	    ,RES1.XmlNod.value('(./data[@name="employer_length_months"])[1]','VARCHAR(100)') AS employeeMonths_BAL
	    ,RES1.XmlNod.value('(./data[@name="loan_amount_desired"])[1]','VARCHAR(100)') AS loanAmount_BAL
	    ,CASE WHEN AppInfo.totalApplicants = 0 THEN 1 ELSE AppInfo.totalApplicants END totalApplicants_BAL
	    ,CASE WHEN  AppInfoStatus.Type IS NULL THEN '' ELSE AppInfoStatus.Type END AS lastApplicantStatus_BAL
	    ,RES1.XmlNod.value('(./data[@name="sub_id"])[1]','VARCHAR(100)') AS subId_BAL
FROM  [Mypayday].[dbo].[BuyAppsLog] BAL WITH(NOLOCK)
left join [MPD-NAT].[dbo].[LIRenewalLead] LRL with(nolock)
    on LRL.[BuyAppsLogID] = BAL.[BuyAppsLogID]
left join [MPD-NAT].[dbo].[LIRenewalLog] LRLog with(nolock) 
    on LRLog.ID =LRL.[LIRenewalLogID]
left join [MPD-NAT].[dbo].[payday] payday with(nolock) 
    on payday.ID = LRLog.CustID
left join [MPD-FBDB].dbo.FB	WITH (NOLOCK)
	ON FB.SS = payday.Social
left outer JOIN Mypayday.dbo.Applicant APP WITH (NOLOCK)
    ON BAL.ApplicantID = APP.ID 
left join Mypayday.[dbo].[ApplicantMapping] APPMap WITH(NOLOCK) 
	ON BAL.ApplicantID=APPMAP.ApplicantID
LEFT JOIN Mypayday.[dbo].[HigherLoanLog] Higher WITH(NOLOCK) 
	ON Higher.[ApplicantMappingId]= APPMap.ApplicantMappingID
left outer join mypayday.dbo.[States] states with(nolock) 
    on app.state=states.name
LEFT OUTER JOIN Mypayday.dbo.Affiliate AFF WITH (NOLOCK)
    ON aff.[Username] = BAL.[Username]
LEFT JOIN [Mypayday].[dbo].[AutomaticLoanFailureReasonByApplicant] AS B WITH (NOLOCK)
	ON BAL.ApplicantID = B.[ApplicantID] 
LEFT JOIN [Mypayday].[dbo].[AutomaticLoanFailureReason] AS C WITH (NOLOCK)
	ON B.AutomaticLoanFailureReasonID = C.AutomaticLoanFailureReasonID
LEFT JOIN Mypayday.dbo.AffiliateContractTracker AS TR
    ON BAL.BuyAppsLogID = TR.BuyAppsLogId

    outer apply
    (
        select 
            status 
        from  [Mypayday].[dbo].[CarrierResponseLog] CRL with(nolock) 
        where CRL.applicantID = app.id and CRL.PhoneType = 'Homephone'
    ) CRLHome
    
    outer apply
    (
        select 
            status 
        from [Mypayday].[dbo].[CarrierResponseLog] CRL with(nolock) 
        where CRL.applicantID = app.id and CRL.PhoneType = 'Cellphone'
    ) CRLCell

    outer apply
    (
        select 
            status,
			convert(xml, Response) as Response_XML
        from  [Mypayday].[dbo].[CarrierResponseLog] CRL with(nolock) 
        where CRL.applicantID = APP.id 
    ) CRL

    OUTER APPLY 
    (
        SELECT
            TOP(1) ID.[Status],
			ID.FraudRiskScore
        FROM
            Mypayday.dbo.IdologyResponseLog AS ID WITH(NOLOCK)
        WHERE
            ID.ApplicantId = APP.id
        ORDER BY
            ID.ResponseDate DESC
    ) IDL

    OUTER APPLY
    (
        SELECT
            TOP(1) GV.ResponseCode
        FROM 
            GatewayACH.dbo.CustomerBankAccount CB WITH(NOLOCK) INNER JOIN GatewayACH.dbo.GverifyLog GV WITH(NOLOCK)
                ON CB.BankAccountID = GV.BankAccountID
        WHERE 
            CB.ApplicantMappingId = APPMap.ApplicantMappingId -- Checking Account table stores the ApplicantMappingId now
            AND DATEDIFF(DAY,GV.InquiryDate,BAL.[Date]) <= 1  -- The inquiry should be done the same day that the lead was received. This prevent inconsistencies
            AND GV.InquiryLocationID IN ('2','5') -- 2 = Application Process, 5 = Lead Posting
        ORDER BY 
            GV.InquiryDate DESC
    ) AS GVC

    OUTER APPLY 
    (
        SELECT
            TOP(1) OpenTransactLog.[OpenTransactResult],
            OpenTransactLog.OpenTransactLogId 
        FROM
            Mypayday.dbo.OpenTransactLog WITH(NOLOCK)
        WHERE
            OpenTransactLog.ApplicantId = APP.id
    ) MB

    OUTER APPLY 
    (
        SELECT TOP 1 
            FTR.*
            ,convert(xml, replace(Response, '<?xml version="1.0" encoding="utf-8" ?>' , '')) as Response_XML
        FROM [Mypayday].[dbo].[FactorTrustResponse] FTR WITH (NOLOCK) 
        WHERE FTR.ApplicantID=APP.ID and FTR.storeID NOT IN ('0020')
    ) FTR

    OUTER APPLY 
    (
        SELECT TOP 1 
            FTR.* 
        FROM [Mypayday].[dbo].[FactorTrustResponse] FTR WITH (NOLOCK) 
        WHERE FTR.ApplicantID=APP.ID and FTR.storeID = '0020'
    ) FTMLA

    OUTER APPLY 
    (
        SELECT TOP 1 
            StoreID,
            RiskScore,
			convert(xml, replace(Response, '<?xml version="1.0" encoding="utf-8" ?>' , '')) as Response_XML 
        FROM mypayday.dbo.factortrustresponse FT with(nolock) 
        where FT.applicantID = APP.ID AND FT.StoreID='0030'
    ) FTR0030

	OUTER APPLY 
	(
		SELECT TOP 1 
			FST.StoreID, 
			FST.Score , 
			FST.PaidOffLoans 
		FROM Mypayday.dbo.FisStoreTwo FST WITH (NOLOCK) WHERE FST.ApplicantID = APP.ID --AND FST.Decision='Approve' 
		ORDER BY FST.FisStoreTwoID ASC
	) FT

    -- To avoid over counting, inquiries made through leads are restricted to be within the next 5 minutes after the app is saved
    OUTER APPLY (
        SELECT 
            COUNT(1) AS TWNInquiries
            ,COALESCE(SUM(CASE WHEN T1.RequestDate < '12/01/18' THEN @TWNPrice1 ELSE @TWNPrice2 END),0) AS TWNCost
        FROM
            Mypayday.dbo.TWNRequestMapping AS T1
        WHERE
            T1.Social = APP.Social
            AND CHARINDEX('"EmployerName":""',T1.Response) = 0
            AND T1.[Source] = 'Leads'
            AND ABS(DATEDIFF(SECOND,DATEADD(HOUR,3,APP.AppDteTme),T1.RequestDate)) <= 300
    ) AS TWNL

    -- Inquiries done through applicant or customer's files.
    OUTER APPLY (
        SELECT 
            COUNT(1) AS TWNInquiries
            ,COALESCE(SUM(CASE WHEN T2.RequestDate < '12/01/18' THEN @TWNPrice1 ELSE @TWNPrice2 END),0) AS TWNCost
        FROM
            Mypayday.dbo.TWNRequestMapping AS T2
        WHERE
            T2.Social = APP.Social
            AND CHARINDEX('"EmployerName":""',T2.Response) = 0
            AND T2.[Source] <> 'Leads'
    ) AS TWNA

    CROSS APPLY (
        SELECT [TWNRequestMapping].Response
        FROM [Mypayday].[dbo].[TWNRequestMapping]
        INNER JOIN [Mypayday].[dbo].ApplicantMapping
        ON [TWNRequestMapping].ApplicantMappingID = ApplicantMapping.ApplicantMappingID
        WHERE  Source = 'LEADS'
        AND ApplicantMapping.ApplicantID = APP.ID
    ) AS TWN

	OUTER APPLY 
	(
		SELECT TOP 1 
            *
		FROM [Mypayday].[dbo].[ScoreModelTracking] SMT WITH (NOLOCK) 
		WHERE SMT.ApplicantID = APP.ID --AND SMT.Decision='Approve' 
		ORDER BY SMT.ScoreModelTrackingID ASC
	) MT

	OUTER APPLY 
	(
		SELECT TOP 1 
            Decision
		FROM [Mypayday].[dbo].[ScoreModelTracking] SMT WITH (NOLOCK) 
		WHERE SMT.ApplicantID = APP.ID AND SMT.Model = 'FactorTrustModel'--AND SMT.Decision='Approve' 
		ORDER BY SMT.ScoreModelTrackingID ASC
	) MT_FT
			
	OUTER APPLY 
	(
		SELECT TOP 1 
			Decision
		FROM [Mypayday].[dbo].[ScoreModelTracking] SMT WITH (NOLOCK) 
		WHERE SMT.ApplicantID = APP.ID AND SMT.Model = 'MLA'--AND SMT.Decision='Approve' 
		ORDER BY SMT.ScoreModelTrackingID DESC
	) MT_MLA
    
    outer apply
    ( 
        select top 1 
            AppNotes.ID,AppNotes.Date  
        from [Mypayday].[dbo].[AppNotes] AppNotes 
        where AppNotes.CustID=app.ID and SubmittedBy<>'999' 
        order by AppNotes.ID 
    ) UWProcessingTime
        
    outer apply
    ( 
        select top 1 
            AppNotes.Date  
        from [Mypayday].[dbo].[AppNotes] AppNotes 
        where AppNotes.CustID=app.ID 
            and SubmittedBy='999' 
            and UWProcessingTime.ID>AppNotes.ID 
            order by AppNotes.ID desc
    ) PassModelTime

    OUTER APPLY 
    (   
        select top 1 
            AppNotes.Date  
        from [Mypayday].[dbo].[AppNotes] AppNotes 
        where AppNotes.CustID=app.ID and convert(varchar,AppNotes.Note) ='CNR'
    ) CNR

    -- Payment Info
	OUTER APPLY 
	(
		SELECT 
			SUM(CASE WHEN CHARINDEX('pay',PT.Type) > 0 THEN 1 ELSE 0 END) TotalPaymentTime
			,SUM(CASE WHEN PT.Type='Renewal' THEN 1 ELSE 0 END) AS RenewTimes
			,SUM(CASE WHEN PT.Type = 'Active -> Written Off' THEN 1 ELSE 0 END) AS WOEntries
			,SUM(CASE WHEN PT.Type = 'Active -> Written Off'  THEN  CONVERT(DECIMAL(18,4),PT.net) ELSE 0 END) AS WrittenOffAmount
			,SUM(CASE WHEN PT.Type IN ('New Loan','Loan IncreASe','Renewal') THEN CONVERT(DECIMAL(18,2), PT.Net) ELSE 0 END) AS TotalLEND
			,SUM(CASE WHEN PT.Type = 'New Loan' THEN CONVERT(DECIMAL(18,2),Net) ELSE 0 END) AS NewLoanAmount
			,SUM(CASE WHEN CHARINDEX('pay',PT.Type) > 0 OR PT.[Type] = 'Return' THEN CONVERT(DECIMAL(18,2),PT.Paidprin) ELSE 0 END) PrincipalPaid
			,SUM(CASE WHEN CHARINDEX('pay',PT.Type) > 0 OR PT.[Type] = 'Return' THEN CONVERT(DECIMAL(18,2),PT.Paidint) ELSE 0 END) Paidint
			,SUM(CASE WHEN CHARINDEX('pay',PT.Type) > 0 OR PT.[Type] = 'Return' THEN CONVERT(DECIMAL(18,2),PT.Payment) ELSE 0 END) TotalPaid
		FROM [MPD-FBDB].dbo.FB  PT WITH (NOLOCK) WHERE PT.SS = FB.SS 
	) FBPayment
				
	OUTER APPLY
	(
		SELECT TOP 1 
			Type 
		FROM [MPD-FBDB].dbo.FB PT WITH (NOLOCK) 
		WHERE PT.SS = FB.SS
		ORDER BY ID DESC
	) LAStTransaction

	OUTER APPLY 
	(
		SELECT TOP 1
			CASE WHEN ATS.Status ='Return' THEN 'Y' ELSE 'N' END AS Returned,
			ATS.ReturnCode
		FROM [MPD-NAT].[dbo].[ACHTransactionStatus] ATS WITH (NOLOCK)
		WHERE ATS.PaydayId = payday.ID AND ATS.TransactionType ='D' 
		ORDER BY  ATS.ACHTransactionStatusId ASC
	) PA

	OUTER APPLY
	(
		SELECT TOP 1 
			PT.*,RV.ID AS RVID 
		FROM [MPD-FBDB].dbo.FB PT WITH (NOLOCK) 
		OUTER APPLY
		(
			SELECT 
				PT.* 
			FROM [MPD-FBDB].dbo.FB Reverts WITH (NOLOCK) 
			WHERE Reverts.[ReferenceTransacction]=PT.ID
		) RV
		WHERE PT.SS = FB.SS 
			AND CHARINDEX('payment',PT.Type) > 0
			AND CHARINDEX('Reverted Pay',PT.Type) = 0
			AND RV.ID IS NULL
			ORDER BY PT.ID ASC
	) FirstPay

    OUTER APPLY 
	(
		SELECT 
			COUNT (*) AS CredictCard 
		FROM Mypayday.DBO.ApplicantMapping AM WITH (NOLOCK) 
		INNER JOIN [MPD-NAT].dbo.CreditCard CC WITH (NOLOCK)
			ON CC.ApplicantMappingID = AM.ApplicantMappingID 
		WHERE AM.PaydayID = payday.ID
	) CP

	CROSS APPLY     
	(SELECT    
		COUNT(*) AS TimesAppliedAll,
		MIN(CASE WHEN CHARINDEX('$',AP.Salary)>0 THEN RIGHT(AP.Salary,LEN(AP.Salary)-1) ELSE CONVERT(DECIMAL(22,8),AP.Salary) END) AS MIN_Salary
	FROM [Mypayday].dbo.Applicant AP WITH (NOLOCK)  
	WHERE AP.Social =APP.Social AND AP.ID <=APP.ID
	) ApplyBefore

	OUTER APPLY     
	(SELECT TOP 1   
		AP.Type AS Pre_Status
	FROM [Mypayday].dbo.Applicant AP WITH (NOLOCK)  
	WHERE AP.Social =APP.Social AND AP.ID < APP.ID
    ORDER BY AP.ID DESC
	) PreviousApp

	CROSS APPLY (
		SELECT 
		   TRY_CAST (REPLACE(REPLACE(B2.XMLin, '<?xml version=''1.0'' encoding=''utf-8''?>', ''), '&','') AS XML) AS XMLINFO
		FROM 
			[Mypayday].[dbo].[BuyAppsLog] AS B2
		WHERE  B2.[BuyAppsLogID] = BAL.[BuyAppsLogID]
	) AS XMLResponse
	 OUTER APPLY XMLResponse.XMLINFO.nodes('/tss_loan_request') AS RES1 (XmlNod)
	 OUTER APPLY ( 
	 SELECT COUNT(*) AS totalApplicants
	 FROM [Mypayday].dbo.Applicant
	 WHERE Applicant.ID = B.ApplicantID
	 AND Applicant.Social = Applicant.Social
	 AND CONVERT(DATE,Applicant.Dte) < CONVERT(DATE,BAL.Date)
	 ) AS AppInfo
	 OUTER APPLY ( 
	 SELECT TOP 1 Applicant.Type 
	 FROM [Mypayday].dbo.Applicant
	 WHERE Applicant.ID = B.ApplicantID
	 AND Applicant.Social = Applicant.Social
	 AND CONVERT(DATE,Applicant.Dte) < CONVERT(DATE,BAL.Date)
	 ORDER BY Applicant.ID DESC
	 ) AS AppInfoStatus

    left join [Mypayday].[dbo].[LeadAutoRejectionXapplicant] LARX with(nolock) 
        on LARX.[BuyAppsLogID]=BAL.[BuyAppsLogID]
    left join [Mypayday].[dbo].[LeadAutoRejectionReason] LRR with(nolock) 
        on LRR.[ID]=LARX.[LeadAutoRejectionID]	
    LEFT OUTER JOIN Mypayday.dbo.ManualRejectionXApplicant MRA WITH (NOLOCK)
        ON MRA.ApplicantId = APP.Id
    LEFT OUTER JOIN Mypayday.dbo.RejectionReasonNote RRN WITH (NOLOCK)
        ON MRA.RejectionReasonNoteId = RRN.RejectionReasonNoteId

    WHERE
    --     --Year(BAL.Date)=Year(@GetDate)
    --     --and datepart(week,bal.date) BETWEEN 23 AND datepart(week,@GetDate)-1
        --Convert(date, bal.date) between @StartDate and @EndDate
		Convert(date, APP.Dte) between @StartDate and @EndDate
        AND APP.ID IS NOT NULL
		AND (APP.ID > 7433312 OR APP.ID IN (select ApplicantId from  [BusinessIntelligence].dbo.IntegrationAnalysisReservedApplicantIds))
        -- AND TWN.Response is not null
        --AND BAL.[DurationInSeconds] > 20
        --AND ISNULL(AFF.LeadPrice,0.00) >0 
        -- and FT.storeID='0030'
        --and CONVERT(DECIMAL(10,2),APP.Loanamount)='500'
        -- and BAL.Status ='accepted'
)

                                                                                                                                                                                        
    select  
	    ApplicantID,
        ReceivedMonth,
        ReceivedDte,
        bankName_BAL AS Bank,
        Routingnum,
        bankAccountMonths_BAL AS Bankaccountlengthmonths,
        monthsAtResidence_BAL AS Monthsatresidence,
        residenceType_BAL AS Residencetype,
        employeeMonths_BAL AS MonthsOnJob,
        monthlyIncome_BAL AS Salary,
        dob_BAL,
        -- DATEDIFF(hour,dob_BAL,ReceivedDte)/8766 AS Age,
        case 
			when DATEDIFF(DAY, CONVERT(DATE,dob_BAL), CONVERT(DATE, ReceivedDte))/365>1000 then DATEDIFF(DAY, CONVERT(DATE,dob_BAL), CONVERT(DATE, ReceivedDte))/365-1000 else DATEDIFF(DAY, CONVERT(DATE,dob_BAL), CONVERT(DATE, ReceivedDte))/365 
		end AS Age,
        RIGHT(RTRIM(emailAddress_BAL), LEN(emailAddress_BAL)-CHARINDEX('@', emailAddress_BAL)) AS Email_Domain,
    	CONVERT(DECIMAL(10,4),CONVERT(DECIMAL(10,2), loanAmount_BAL)*0.3*2/(CONVERT(DECIMAL(18,2),REPLACE(monthlyIncome_BAL,'$',''))*1.0)) AS Payment_ratio,
        Directdeposit,
        state_BAL AS State,
        abbr, 
        Pre_Status,
        totalApplicants_BAL AS TimesAppliedAll,
        IDologyStatus,
        RiskScore, 
        NewFT_Score,
        FT_Decision,
        MLA_Decision,
        MLA,
        PaidOffLoans_NewFT,
        PaidOffLoans,
        CreditCardProvided,
        StoreID, 
        ApplicantType,
        IfAccepted,
        IfFunded,
        BuyStatus,
        loanAmount_BAL AS Loanamount,
        OriginalAmount,
        HigherAmountSelected,
		SellType,
        Affiliate,
        AggregatedAFF,
        subId_BAL AS SubID,
        leadprice,
        FraudRiskScore,
        CarrierName,
	    AutomaticLoanProcessSuccessful,
        IsAutomaticLoanApproved,
        FailureReason,Type2,
	    ReceivedDte,
        ReceivedMonth,
        TWNResponse,
        -- ReceivedYear,
        -- WeekNum,
        -- ReceivedHour,
        -- DayName,
        -- WorkingHour,
        -- PassModelTime,
        -- FCMTime,
        -- ResponseTime,
        -- ResponseTime_second,
        IsCNR,
        IsTWNVerified,
        ViewContractDate,
        SignatureDate,
        LinkOpenDate,
        RejectionReason,
	    CarrierCellCost,
        CarrierHomeCost,
        MicrobiltCost,
        -- gVerifyCost, 
        IDologyCost, 
        LoanPerformanceCost + IdLogicCost + ChexAdvisorCost + TUAttributesCost + MlaCost AS FTCost,
		TWNResponse,
        TWNCost,
        TWNInquiries,
        LoanPerformanceCost,
        IdLogicCost,
        ChexAdvisorCost,
        TUAttributesCost,
        MlaCost,
        -- IdologyCost + GverifyCost + CarrierCellCost + CarrierHomeCost + LoanPerformanceCost + IdLogicCost + ChexAdvisorCost + TUAttributesCost + MlaCost + TWNCost AS DataCost,
        IdologyCost + MicrobiltCost + LoanPerformanceCost + IdLogicCost + ChexAdvisorCost + TUAttributesCost + MlaCost + TWNCost AS DataCost,
        NewLoanLeadCost
        -- RenewalLeadCost, 
        -- IdologyCost + GverifyCost + CarrierCellCost + CarrierHomeCost + LoanPerformanceCost + IdLogicCost + ChexAdvisorCost + TUAttributesCost + MlaCost + TWNCost + NewLoanLeadCost + RenewalLeadCost AS TotalAcquisitionCost,
        -- FPD,
        -- FPF,
        -- Defaulted,
        -- Cycled,
        -- TotalPaid,
        -- TotalLEND,
        -- TotalPaymentTime,
        -- NewLoanAmount,
        -- NewLoanAmount	
    FROM AffTracker 