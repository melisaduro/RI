-------------------------------------		
	-- 1.5) Estadisticos	3GOnly_4G 
	-------------------------------------		
	print '1.5. Insert Estadisticos 3GOnly_4G y 3GOnly_Roads - DL/UL/WEB/YTB' 	
	-----------
	-- 3GOnly_4G y ROAD - CE_DL
	insert into _RI_Data_e 
	select		
		p.codigo_ine, case when  t.entidad like 'AVE-%' or  t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'3GOnly_4G' as meas_Tech, 'CE_DL' as Test_type, 'Downlink' as Direction,  t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
	
		-- General:
		sum(O3G.navegaciones) as Num_tests,
		sum(O3G.[fallos de acceso]) as Failed,
		sum(O3G.[fallos de descarga]) as Dropped,
		sum(O3G.[SessionTime]*O3G.navegaciones) as Session_time_Num,
		--sum(O3G.[tiempo de descarga]*O3G.count_throughput) as Session_time_Num,	-- SESSION_TIME de DL/UL, calculado como TRANSFER_TIME - se haría el cambio al calculo correcto en cambio de metodología para evitar salto de valor en QLIK.
		sum(O3G.count_throughput) as Throughput_Den,
		sum(O3G.navegaciones) as Session_time_Den,
		--sum(O3G.count_throughput) as Session_time_Den,
		sum(O3G.Throughput*O3G.count_throughput) as Throughput_Num,
		max(O3G.[Throughput Max]) as Throughput_Max,
		sum(O3G.Count_Throughput_3M) as Throughput_3M_Num,
		sum(O3G.Count_Throughput_1M) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(O3G.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(O3G.Throughput_ALL*O3G.Count_Throughput_ALL) as Throughput_with_Error_Num,
		
		sum(0) as WEB_IP_ACCESS_TIME_NUM,			sum(0) as WEB_IP_ACCESS_TIME_DEN,	
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,	sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,
		
		-- Technology:
		sum(tel.[% GSM]*tel.[Count_%GSM]) as Radio_2G_use_Num,
		sum(tel.[% WCDMA]*tel.[Count_%WCDMA]) as Radio_3G_use_Num,
		sum(tel.[% LTE]*tel.[Count_%LTE]) as Radio_4G_use_Num,
		sum(O3G.navegaciones*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(O3G.navegaciones*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,
		sum(tel.[Count_%U2100]) as Radio_U2100_use_Den,
		sum(tel.[Count_%U900]) as Radio_U900_use_Den,
		sum(tel.[Count_%LTE2100]) as Radio_LTE2100_use_Den,
		sum(tel.[Count_%LTE2600]) as Radio_LTE2600_use_Den,
		sum(tel.[Count_%LTE1800]) as Radio_LTE1800_use_Den,
		sum(tel.[Count_%LTE800]) as Radio_LTE800_use_Den,

		-- Solo en DL:
		sum(tel.[% Dual Carrier]*tel.[Count_Dual_Carrier]) as [3G_DualCarrier_use_Num],	sum(tel.[Count_Dual_Carrier]) as [3G_DualCarrier_use_Den],
		sum(tel.[%DC_U2100]*tel.[Count_DC_U2100]) as [3G_DC_2100_use_Num],				sum(tel.[Count_DC_U2100]) as [3G_DC_2100_use_Den],
		sum(tel.[%DC_U900]*tel.[Count_DC_U900]) as [3G_DC_900_use_Num],					sum(tel.[Count_DC_U900]) as [3G_DC_900_use_Den],

		sum(tel.[Num Codes]*tel.[Count_Num_Codes]) as [3G_NumCodes_use_Num],
		sum(tel.[Count_Num_Codes]) as [3G_NumCodes_use_Den],

		sum(tel.[QPSK]*tel.[Count_QPSK]) as [3G_QPSK_use_Num],
		sum(tel.[16QAM]*tel.[Count_16QAM]) as [3G_16QAM_use_Num],
		sum(tel.[64QAM]*tel.[Count_64QAM]) as [3G_64QAM_use_Num],
		sum(tel.[Count_QPSK]) as [3G_QPSK_use_Den],
		sum(tel.[Count_16QAM]) as [3G_16QAM_use_Den],
		sum(tel.[Count_64QAM]) as [3G_64QAM_use_Den],

		-- Solo en UL:
		sum(0) as [3G_%_SF22_Num],		sum(0) as [3G_%_SF22andSF42_Num],	sum(0) as [3G_%_SF4_Num],	sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],		sum(0) as [3G_%_SF22andSF42_Den],	sum(0) as [3G_%_SF4_Den],	sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],	sum(0) as [3G_%_TTI2ms_Den],

		-- Ambos:
		sum(tel.[RSCP_Lin]*tel.[Count_RSCP_Lin]) as [RSCP_Lin_Num],
		sum(tel.[EcI0_Lin]*tel.[Count_EcI0_Lin]) as [EcI0_Lin_Num],	
		sum(tel.[Count_RSCP_Lin]) as [RSCP_Lin_Den],	
		sum(tel.[Count_EcI0_Lin]) as [EcI0_Lin_Den],	

		-- Performance:
		sum(pfl.CQI*(isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) [3G_CQI],
		sum((isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) as [3G_DataStats_Den],
		Sum(pfl.CQI_U900*isnull(pfl.count_cqi_u900,0)) as CQI_U900_Num,
		sum(isnull(pfl.count_cqi_u900,0)) as CQI_U900_Den,
		Sum(pfl.CQI_U2100*isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Num,
		sum(isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Den,

		sum(pfl.[HSPA_PCT]*pfl.[Count_HSPA]) as [HSPA_PCT_Num],
		sum(pfl.[HSPA+_PCT]*pfl.[Count_HSPA+]) as [HSPA+_PCT_Num],
		sum(pfl.[HSPA+_DC_PCT]*pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Num],
		sum(pfl.[Count_HSPA]) as [HSPA_PCT_Den],
		sum(pfl.[Count_HSPA+]) as [HSPA+_PCT_Den],
		sum(pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Den],

		sum(pfl.[UL_Inter_Lin]*pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Num],
		sum(pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Den],	
	
		-- Performance LTE (no tienen sentido en 3GOnly):
		sum(0) as CQI_4G_Num,		sum(0) as CQI_L800_Num,		sum(0) as CQI_L1800_Num,		sum(0) as CQI_L2100_Num,		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,		sum(0) as CQI_L800_Den,		sum(0) as CQI_L1800_Den,		sum(0) as CQI_L2100_Den,		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,	sum(0) as LTE_10Mhz_SC_Use_Num,	sum(0) as LTE_15Mhz_SC_Use_Num,	sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,	sum(0) as LTE_20Mhz_CA_Use_Num,	sum(0) as LTE_25Mhz_CA_Use_Num,	sum(0) as LTE_30Mhz_CA_Use_Num,	sum(0) as LTE_35Mhz_CA_Use_Num,	sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,	sum(0) as LTE_10Mhz_SC_Use_Den,	sum(0) as LTE_15Mhz_SC_Use_Den,	sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,	sum(0) as LTE_20Mhz_CA_Use_Den,	sum(0) as LTE_25Mhz_CA_Use_Den,	sum(0) as LTE_30Mhz_CA_Use_Den,	sum(0) as LTE_35Mhz_CA_Use_Den,	sum(0) as LTE_40Mhz_CA_Use_Den,	

		sum(0) as LTE_BW_use_den,	sum(0) as [4G_RBs_use_Num],	sum(0) as [4G_RBs_use_Den],
	
		sum(0) as [4G_TM1_use_Num],			sum(0) as [4G_TM2_use_Num],			sum(0) as [4G_TM3_use_Num],		sum(0) as [4G_TM4_use_Num],		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],			sum(0) as [4G_TM7_use_Num],			sum(0) as [4G_TM8_use_Num],		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],	sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE(no tienen sentido en 3GOnly):
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs(no tienen sentido en 3GOnly):
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:
		sum(isnull(O3G.[ 0-2Mbps_N ],0)) as [1_N],		sum(isnull(O3G.[ 2-4Mbps_N ],0)) as [2_N],		sum(isnull(O3G.[ 4-6Mbps_N ],0)) as [3_N],		sum(isnull(O3G.[ 6-8Mbps_N ],0)) as [4_N],		sum(isnull(O3G.[ 8-10Mbps_N ],0)) as [5_N],
		sum(isnull(O3G.[ 10-12Mbps_N ],0)) as [6_N],		sum(isnull(O3G.[ 12-14Mbps_N ],0)) as [7_N],		sum(isnull(O3G.[ 14-16Mbps_N ],0)) as [8_N],		sum(isnull(O3G.[ 16-18Mbps_N ],0)) as [9_N],		sum(isnull(O3G.[ 18-20Mbps_N ],0)) as [10_N],
		sum(isnull(O3G.[ 20-22Mbps_N ],0)) as [11_N],		sum(isnull(O3G.[ 22-24Mbps_N ],0)) as [12_N],		sum(isnull(O3G.[ 24-26Mbps_N ],0)) as [13_N],		sum(isnull(O3G.[ 26-28Mbps_N ],0)) as [14_N],		sum(isnull(O3G.[ 28-30Mbps_N ],0)) as [15_N],
		sum(isnull(O3G.[ 30-32Mbps_N ],0)) as [16_N],		sum(isnull(O3G.[ 32-34Mbps_N ],0)) as [17_N],		sum(isnull(O3G.[ 34-36Mbps_N ],0)) as [18_N],		sum(isnull(O3G.[ 36-38Mbps_N ],0)) as [19_N],		sum(isnull(O3G.[ 38-40Mbps_N ],0)) as [20_N],
		sum(isnull(O3G.[ 40-42Mbps_N ],0)) as [21_N],		sum(isnull(O3G.[ 42-44Mbps_N ],0)) as [22_N],		sum(isnull(O3G.[ 44-46Mbps_N ],0)) as [23_N],		sum(isnull(O3G.[ 46-48Mbps_N ],0)) as [24_N],		sum(isnull(O3G.[ 48-50Mbps_N ],0)) as [25_N],
		sum(isnull(O3G.[ 50-52Mbps_N ],0)) as [26_N],		sum(isnull(O3G.[ 52-54Mbps_N ],0)) as [27_N],		sum(isnull(O3G.[ 54-56Mbps_N ],0)) as [28_N],		sum(isnull(O3G.[ 56-58Mbps_N ],0)) as [29_N],		sum(isnull(O3G.[ 58-60Mbps_N ],0)) as [30_N],
		sum(isnull(O3G.[ 60-62Mbps_N ],0)) as [31_N],		sum(isnull(O3G.[ 62-64Mbps_N ],0)) as [32_N],		sum(isnull(O3G.[ 64-66Mbps_N ],0)) as [33_N],		sum(isnull(O3G.[ 66-68Mbps_N ],0)) as [34_N],		sum(isnull(O3G.[ 68-70Mbps_N ],0)) as [35_N],
		sum(isnull(O3G.[ 70-72Mbps_N ],0)) as [36_N],		sum(isnull(O3G.[ 72-74Mbps_N ],0)) as [37_N],		sum(isnull(O3G.[ 74-76Mbps_N ],0)) as [38_N],		sum(isnull(O3G.[ 76-78Mbps_N ],0)) as [39_N],		sum(isnull(O3G.[ 78-80Mbps_N ],0)) as [40_N],
		sum(isnull(O3G.[ 80-82Mbps_N ],0)) as [41_N],		sum(isnull(O3G.[ 82-84Mbps_N ],0)) as [42_N],		sum(isnull(O3G.[ 84-86Mbps_N ],0)) as [43_N],		sum(isnull(O3G.[ 86-88Mbps_N ],0)) as [44_N],		sum(isnull(O3G.[ 88-90Mbps_N ],0)) as [45_N],
		sum(isnull(O3G.[ 90-92Mbps_N ],0)) as [46_N],		sum(isnull(O3G.[ 92-94Mbps_N ],0)) as [47_N],		sum(isnull(O3G.[ 94-96Mbps_N ],0)) as [48_N],		sum(isnull(O3G.[ 96-98Mbps_N ],0)) as [49_N],		sum(isnull(O3G.[ 98-100Mbps_N ],0)) as [50_N],
		sum(isnull(O3G.[ >100Mbps_N],0)) as [51_N],	
		sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(isnull(O3G.[ 0-5Mbps],0)) as [1]			,sum(isnull(O3G.[ 5-10Mbps],0)) as [2]		,sum(isnull(O3G.[ 10-15Mbps],0)) as [3]		,sum(isnull(O3G.[ 15-20Mbps],0)) as [4]		,sum(isnull(O3G.[ 20-25Mbps],0)) as [5]
		,sum(isnull(O3G.[ 25-30Mbps],0)) as [6]		,sum(isnull(O3G.[ 30-35Mbps],0)) as [7]		,sum(isnull(O3G.[ 35-40Mbps],0)) as [8]		,sum(isnull(O3G.[ 40-45Mbps],0)) as [9]		,sum(isnull(O3G.[ 45-50Mbps],0)) as [10]
		,sum(isnull(O3G.[ 50-55Mbps],0)) as [11]		,sum(isnull(O3G.[ 55-60Mbps],0)) as [12]		,sum(isnull(O3G.[ 60-65Mbps],0)) as [13]		,sum(isnull(O3G.[ 65-70Mbps],0)) as [14]		,sum(isnull(O3G.[ 70-75Mbps],0)) as [15]
		,sum(isnull(O3G.[ 75-80Mbps],0)) as [16]		,sum(isnull(O3G.[ 80-85Mbps],0)) as [17]		,sum(isnull(O3G.[ 85-90Mbps],0)) as [18]		,sum(isnull(O3G.[ 90-95Mbps],0)) as [19]		,sum(isnull(O3G.[ 95-100Mbps],0)) as [20]
		,sum(isnull(O3G.[ 100-105Mbps],0)) as [21]	,sum(isnull(O3G.[ 105-110Mbps],0)) as [22]	,sum(isnull(O3G.[ 110-115Mbps],0)) as [23]	,sum(isnull(O3G.[ 115-120Mbps],0)) as [24]	,sum(isnull(O3G.[ 120-125Mbps],0)) as [25]
		,sum(isnull(O3G.[ 125-130Mbps],0)) as [26]	,sum(isnull(O3G.[ 130-135Mbps],0)) as [27]	,sum(isnull(O3G.[ 135-140Mbps],0)) as [28]	,sum(isnull(O3G.[ 140-145Mbps],0)) as [29]	,sum(isnull(O3G.[ 145-150Mbps],0)) as [30]
		,sum(isnull(O3G.[ >150Mbps],0)) as [31]
		,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]	,sum(0) as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_DL_Thput_CE] t
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_DL_Performance_CE_LTE_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_DL_Technology_CE_LTE_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_DL_Thput_CE_LTE_3G] O3G
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(O3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=O3G.mnc and t.Date_Reporting=O3G.Date_Reporting and t.entidad=O3G.entidad and t.Aggr_Type=O3G.Aggr_Type and t.Report_Type=O3G.Report_Type and t.meas_round=O3G.meas_round
				, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when  t.entidad like 'AVE-%' or  t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP

	-----------
	union all	-- Road 3GOnly - CE_DL	
	select  
		p.codigo_ine, 'Roads' vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'Road 3GOnly' as meas_Tech, 'CE_DL' as Test_type, 'Downlink' as Direction,  t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
	
		-- General:
		sum(O3G.navegaciones) as Num_tests,
		sum(O3G.[fallos de acceso]) as Failed,
		sum(O3G.[fallos de descarga]) as Dropped,
		sum(O3G.[SessionTime]*O3G.navegaciones) as Session_time_Num,
		--sum(O3G.[tiempo de descarga]*O3G.count_throughput) as Session_time_Num,	-- SESSION_TIME de DL/UL, calculado como TRANSFER_TIME - se haría el cambio al calculo correcto en cambio de metodología para evitar salto de valor en QLIK.
		sum(O3G.count_throughput) as Throughput_Den,
		sum(O3G.navegaciones) as Session_time_Den,
		--sum(O3G.count_throughput) as Session_time_Den,
		sum(O3G.Throughput*O3G.count_throughput) as Throughput_Num,
		max(O3G.[Throughput Max]) as Throughput_Max,
		sum(O3G.Count_Throughput_3M) as Throughput_3M_Num,
		sum(O3G.Count_Throughput_1M) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(O3G.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(O3G.Throughput_ALL*O3G.Count_Throughput_ALL) as Throughput_with_Error_Num,
		
		sum(0) as WEB_IP_ACCESS_TIME_NUM,			sum(0) as WEB_IP_ACCESS_TIME_DEN,	
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,	sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(tel.[% GSM]*tel.[Count_%GSM]) as Radio_2G_use_Num,
		sum(tel.[% WCDMA]*tel.[Count_%WCDMA]) as Radio_3G_use_Num,
		sum(tel.[% LTE]*tel.[Count_%LTE]) as Radio_4G_use_Num,
		sum(O3G.navegaciones*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(O3G.navegaciones*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,
		sum(tel.[Count_%U2100]) as Radio_U2100_use_Den,
		sum(tel.[Count_%U900]) as Radio_U900_use_Den,
		sum(tel.[Count_%LTE2100]) as Radio_LTE2100_use_Den,
		sum(tel.[Count_%LTE2600]) as Radio_LTE2600_use_Den,
		sum(tel.[Count_%LTE1800]) as Radio_LTE1800_use_Den,
		sum(tel.[Count_%LTE800]) as Radio_LTE800_use_Den,

		-- Solo en DL:
		sum(tel.[% Dual Carrier]*tel.[Count_Dual_Carrier]) as [3G_DualCarrier_use_Num],	sum(tel.[Count_Dual_Carrier]) as [3G_DualCarrier_use_Den],
		sum(tel.[%DC_U2100]*tel.[Count_DC_U2100]) as [3G_DC_2100_use_Num],				sum(tel.[Count_DC_U2100]) as [3G_DC_2100_use_Den],
		sum(tel.[%DC_U900]*tel.[Count_DC_U900]) as [3G_DC_900_use_Num],					sum(tel.[Count_DC_U900]) as [3G_DC_900_use_Den],

		sum(tel.[Num Codes]*tel.[Count_Num_Codes]) as [3G_NumCodes_use_Num],
		sum(tel.[Count_Num_Codes]) as [3G_NumCodes_use_Den],

		sum(tel.[QPSK]*tel.[Count_QPSK]) as [3G_QPSK_use_Num],
		sum(tel.[16QAM]*tel.[Count_16QAM]) as [3G_16QAM_use_Num],
		sum(tel.[64QAM]*tel.[Count_64QAM]) as [3G_64QAM_use_Num],
		sum(tel.[Count_QPSK]) as [3G_QPSK_use_Den],
		sum(tel.[Count_16QAM]) as [3G_16QAM_use_Den],
		sum(tel.[Count_64QAM]) as [3G_64QAM_use_Den],

		-- Solo en UL:
		sum(0) as [3G_%_SF22_Num],		sum(0) as [3G_%_SF22andSF42_Num],	sum(0) as [3G_%_SF4_Num],	sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],		sum(0) as [3G_%_SF22andSF42_Den],	sum(0) as [3G_%_SF4_Den],	sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],	sum(0) as [3G_%_TTI2ms_Den],

		-- Ambos:
		sum(tel.[RSCP_Lin]*tel.[Count_RSCP_Lin]) as [RSCP_Lin_Num],
		sum(tel.[EcI0_Lin]*tel.[Count_EcI0_Lin]) as [EcI0_Lin_Num],	
		sum(tel.[Count_RSCP_Lin]) as [RSCP_Lin_Den],	
		sum(tel.[Count_EcI0_Lin]) as [EcI0_Lin_Den],	

		-- Performance:
		sum(pfl.CQI*(isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) [3G_CQI],
		sum((isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) as [3G_DataStats_Den],
		Sum(pfl.CQI_U900*isnull(pfl.count_cqi_u900,0)) as CQI_U900_Num,
		sum(isnull(pfl.count_cqi_u900,0)) as CQI_U900_Den,
		Sum(pfl.CQI_U2100*isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Num,
		sum(isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Den,

		sum(pfl.[HSPA_PCT]*pfl.[Count_HSPA]) as [HSPA_PCT_Num],
		sum(pfl.[HSPA+_PCT]*pfl.[Count_HSPA+]) as [HSPA+_PCT_Num],
		sum(pfl.[HSPA+_DC_PCT]*pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Num],
		sum(pfl.[Count_HSPA]) as [HSPA_PCT_Den],
		sum(pfl.[Count_HSPA+]) as [HSPA+_PCT_Den],
		sum(pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Den],

		sum(pfl.[UL_Inter_Lin]*pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Num],
		sum(pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Den],	
	
		-- Performance LTE (no tienen sentido en 3GOnly):
		sum(0) as CQI_4G_Num,		sum(0) as CQI_L800_Num,		sum(0) as CQI_L1800_Num,		sum(0) as CQI_L2100_Num,		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,		sum(0) as CQI_L800_Den,		sum(0) as CQI_L1800_Den,		sum(0) as CQI_L2100_Den,		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,	sum(0) as LTE_10Mhz_SC_Use_Num,	sum(0) as LTE_15Mhz_SC_Use_Num,	sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,	sum(0) as LTE_20Mhz_CA_Use_Num,	sum(0) as LTE_25Mhz_CA_Use_Num,	sum(0) as LTE_30Mhz_CA_Use_Num,	sum(0) as LTE_35Mhz_CA_Use_Num,	sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,	sum(0) as LTE_10Mhz_SC_Use_Den,	sum(0) as LTE_15Mhz_SC_Use_Den,	sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,	sum(0) as LTE_20Mhz_CA_Use_Den,	sum(0) as LTE_25Mhz_CA_Use_Den,	sum(0) as LTE_30Mhz_CA_Use_Den,	sum(0) as LTE_35Mhz_CA_Use_Den,	sum(0) as LTE_40Mhz_CA_Use_Den,	

		sum(0) as LTE_BW_use_den,	sum(0) as [4G_RBs_use_Num],	sum(0) as [4G_RBs_use_Den],
	
		sum(0) as [4G_TM1_use_Num],			sum(0) as [4G_TM2_use_Num],			sum(0) as [4G_TM3_use_Num],		sum(0) as [4G_TM4_use_Num],		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],			sum(0) as [4G_TM7_use_Num],			sum(0) as [4G_TM8_use_Num],		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],	sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE(no tienen sentido en 3GOnly):
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs(no tienen sentido en 3GOnly):
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:
		sum(isnull(O3G.[ 0-2Mbps_N ],0)) as [1_N],		sum(isnull(O3G.[ 2-4Mbps_N ],0)) as [2_N],		sum(isnull(O3G.[ 4-6Mbps_N ],0)) as [3_N],		sum(isnull(O3G.[ 6-8Mbps_N ],0)) as [4_N],		sum(isnull(O3G.[ 8-10Mbps_N ],0)) as [5_N],
		sum(isnull(O3G.[ 10-12Mbps_N ],0)) as [6_N],	sum(isnull(O3G.[ 12-14Mbps_N ],0)) as [7_N],	sum(isnull(O3G.[ 14-16Mbps_N ],0)) as [8_N],	sum(isnull(O3G.[ 16-18Mbps_N ],0)) as [9_N],	sum(isnull(O3G.[ 18-20Mbps_N ],0)) as [10_N],
		sum(isnull(O3G.[ 20-22Mbps_N ],0)) as [11_N],	sum(isnull(O3G.[ 22-24Mbps_N ],0)) as [12_N],	sum(isnull(O3G.[ 24-26Mbps_N ],0)) as [13_N],	sum(isnull(O3G.[ 26-28Mbps_N ],0)) as [14_N],	sum(isnull(O3G.[ 28-30Mbps_N ],0)) as [15_N],
		sum(isnull(O3G.[ 30-32Mbps_N ],0)) as [16_N],	sum(isnull(O3G.[ 32-34Mbps_N ],0)) as [17_N],	sum(isnull(O3G.[ 34-36Mbps_N ],0)) as [18_N],	sum(isnull(O3G.[ 36-38Mbps_N ],0)) as [19_N],	sum(isnull(O3G.[ 38-40Mbps_N ],0)) as [20_N],
		sum(isnull(O3G.[ 40-42Mbps_N ],0)) as [21_N],	sum(isnull(O3G.[ 42-44Mbps_N ],0)) as [22_N],	sum(isnull(O3G.[ 44-46Mbps_N ],0)) as [23_N],	sum(isnull(O3G.[ 46-48Mbps_N ],0)) as [24_N],	sum(isnull(O3G.[ 48-50Mbps_N ],0)) as [25_N],
		sum(isnull(O3G.[ 50-52Mbps_N ],0)) as [26_N],	sum(isnull(O3G.[ 52-54Mbps_N ],0)) as [27_N],	sum(isnull(O3G.[ 54-56Mbps_N ],0)) as [28_N],	sum(isnull(O3G.[ 56-58Mbps_N ],0)) as [29_N],	sum(isnull(O3G.[ 58-60Mbps_N ],0)) as [30_N],
		sum(isnull(O3G.[ 60-62Mbps_N ],0)) as [31_N],	sum(isnull(O3G.[ 62-64Mbps_N ],0)) as [32_N],	sum(isnull(O3G.[ 64-66Mbps_N ],0)) as [33_N],	sum(isnull(O3G.[ 66-68Mbps_N ],0)) as [34_N],	sum(isnull(O3G.[ 68-70Mbps_N ],0)) as [35_N],
		sum(isnull(O3G.[ 70-72Mbps_N ],0)) as [36_N],	sum(isnull(O3G.[ 72-74Mbps_N ],0)) as [37_N],	sum(isnull(O3G.[ 74-76Mbps_N ],0)) as [38_N],	sum(isnull(O3G.[ 76-78Mbps_N ],0)) as [39_N],	sum(isnull(O3G.[ 78-80Mbps_N ],0)) as [40_N],
		sum(isnull(O3G.[ 80-82Mbps_N ],0)) as [41_N],	sum(isnull(O3G.[ 82-84Mbps_N ],0)) as [42_N],	sum(isnull(O3G.[ 84-86Mbps_N ],0)) as [43_N],	sum(isnull(O3G.[ 86-88Mbps_N ],0)) as [44_N],	sum(isnull(O3G.[ 88-90Mbps_N ],0)) as [45_N],
		sum(isnull(O3G.[ 90-92Mbps_N ],0)) as [46_N],	sum(isnull(O3G.[ 92-94Mbps_N ],0)) as [47_N],	sum(isnull(O3G.[ 94-96Mbps_N ],0)) as [48_N],	sum(isnull(O3G.[ 96-98Mbps_N ],0)) as [49_N],	sum(isnull(O3G.[ 98-100Mbps_N ],0)) as [50_N],
		sum(isnull(O3G.[ >100Mbps_N],0)) as [51_N],	
		sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	
		sum(0) as [60_N],	sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--t.Region_VF as Region_Road_VF, t.Region_OSP as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(isnull(O3G.[ 0-5Mbps],0)) as [1]			,sum(isnull(O3G.[ 5-10Mbps],0)) as [2]		,sum(isnull(O3G.[ 10-15Mbps],0)) as [3]		,sum(isnull(O3G.[ 15-20Mbps],0)) as [4]		,sum(isnull(O3G.[ 20-25Mbps],0)) as [5]
		,sum(isnull(O3G.[ 25-30Mbps],0)) as [6]		,sum(isnull(O3G.[ 30-35Mbps],0)) as [7]		,sum(isnull(O3G.[ 35-40Mbps],0)) as [8]		,sum(isnull(O3G.[ 40-45Mbps],0)) as [9]		,sum(isnull(O3G.[ 45-50Mbps],0)) as [10]
		,sum(isnull(O3G.[ 50-55Mbps],0)) as [11]		,sum(isnull(O3G.[ 55-60Mbps],0)) as [12]		,sum(isnull(O3G.[ 60-65Mbps],0)) as [13]		,sum(isnull(O3G.[ 65-70Mbps],0)) as [14]		,sum(isnull(O3G.[ 70-75Mbps],0)) as [15]
		,sum(isnull(O3G.[ 75-80Mbps],0)) as [16]		,sum(isnull(O3G.[ 80-85Mbps],0)) as [17]		,sum(isnull(O3G.[ 85-90Mbps],0)) as [18]		,sum(isnull(O3G.[ 90-95Mbps],0)) as [19]		,sum(isnull(O3G.[ 95-100Mbps],0)) as [20]
		,sum(isnull(O3G.[ 100-105Mbps],0)) as [21]	,sum(isnull(O3G.[ 105-110Mbps],0)) as [22]	,sum(isnull(O3G.[ 110-115Mbps],0)) as [23]	,sum(isnull(O3G.[ 115-120Mbps],0)) as [24]	,sum(isnull(O3G.[ 120-125Mbps],0)) as [25]
		,sum(isnull(O3G.[ 125-130Mbps],0)) as [26]	,sum(isnull(O3G.[ 130-135Mbps],0)) as [27]	,sum(isnull(O3G.[ 135-140Mbps],0)) as [28]	,sum(isnull(O3G.[ 140-145Mbps],0)) as [29]	,sum(isnull(O3G.[ 145-150Mbps],0)) as [30]
		,sum(isnull(O3G.[ >150Mbps],0)) as [31]
		,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]	,sum(0) as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from	[aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_DL_Thput_CE] t
				left outer join [aggrData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_DL_Performance_CE_LTE_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round
				left outer join [aggrData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_DL_Technology_CE_LTE_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round
				left outer join [aggrData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_DL_Thput_CE_LTE_3G] O3G
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(O3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=O3G.mnc and t.Date_Reporting=O3G.Date_Reporting and t.entidad=O3G.entidad and t.Aggr_Type=O3G.Aggr_Type and t.Report_Type=O3G.Report_Type and t.meas_round=O3G.meas_round
				, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP

	-----------
	-- 3GOnly_4G y ROAD - CE_UL
	insert into _RI_Data_e 
	select  
		p.codigo_ine, case when  t.entidad like 'AVE-%' or  t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'3GOnly_4G' as meas_Tech, 'CE_UL' as Test_type, 'Uplink' as Direction,  t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
	
		-- General:
		sum(O3G.Subidas) as Num_tests,
		sum(O3G.[fallos de acceso]) as Failed,
		sum(O3G.[fallos de descarga]) as Dropped,
		sum(O3G.[SessionTime]*O3G.Subidas) as Session_time_Num,
		--sum(O3G.[Tiempo de subida]*O3G.count_throughput) as Session_time_Num,	-- SESSION_TIME de DL/UL, calculado como TRANSFER_TIME - se haría el cambio al calculo correcto en cambio de metodología para evitar salto de valor en QLIK.
		sum(O3G.count_throughput) as Throughput_Den,
		sum(O3G.Subidas) as Session_time_Den,
		--sum(O3G.count_throughput) as Session_time_Den,
		sum(O3G.Throughput*O3G.count_throughput) as Throughput_Num,
		max(O3G.[Throughput Max]) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(O3G.Count_Throughput_1M) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(O3G.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(O3G.Throughput_ALL*O3G.Count_Throughput_ALL) as Throughput_with_Error_Num,
		
		sum(0) as WEB_IP_ACCESS_TIME_NUM,			sum(0) as WEB_IP_ACCESS_TIME_DEN,	
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,	sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(tel.[% GSM]*tel.[Count_%GSM]) as Radio_2G_use_Num,
		sum(tel.[% WCDMA]*tel.[Count_%WCDMA]) as Radio_3G_use_Num,
		sum(tel.[% LTE]*tel.[Count_%LTE]) as Radio_4G_use_Num,
		sum(O3G.subidas*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(O3G.subidas*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,
		sum(tel.[Count_%U2100]) as Radio_U2100_use_Den,
		sum(tel.[Count_%U900]) as Radio_U900_use_Den,
		sum(tel.[Count_%LTE2100]) as Radio_LTE2100_use_Den,
		sum(tel.[Count_%LTE2600]) as Radio_LTE2600_use_Den,
		sum(tel.[Count_%LTE1800]) as Radio_LTE1800_use_Den,
		sum(tel.[Count_%LTE800]) as Radio_LTE800_use_Den,

		-- Solo en DL:
		sum(0) as [3G_DualCarrier_use_Num],		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],			sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],			sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],	sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],		sum(0) as [3G_16QAM_use_Num],	sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],		sum(0) as [3G_16QAM_use_Den],	sum(0) as [3G_64QAM_use_Den],

		-- Solo en UL:
		sum((tel.[% SF22]/100.0)*tel.[Count_%_SF22]) as [3G_%_SF22_Num],
		sum((tel.[% SF22andSF42]/100.0)*tel.[Count_%_SF22andSF42]) as [3G_%_SF22andSF42_Num],
		sum((tel.[% SF4]/100.0)*tel.[Count_%SF4]) as [3G_%_SF4_Num],
		sum((tel.[% SF42]/100.0)*tel.[Count_%_SF42]) as [3G_%_SF42_Num],
		sum(tel.[Count_%_SF22]) as [3G_%_SF22_Den],
		sum(tel.[Count_%_SF22andSF42]) as [3G_%_SF22andSF42_Den],
		sum(tel.[Count_%SF4]) as [3G_%_SF4_Den],
		sum(tel.[Count_%_SF42]) as [3G_%_SF42_Den],
		sum(tel.[% TTI 2ms_float]*tel.[Count_%TTI_2ms]) as [3G_%_TTI2ms_Num],
		sum(tel.[Count_%TTI_2ms]) as [3G_%_TTI2ms_Den],

		-- Ambos:
		sum(tel.[RSCP_Lin]*tel.[Count_RSCP_Lin]) as [RSCP_Lin_Num],
		sum(tel.[EcI0_Lin]*tel.[Count_EcI0_Lin]) as [EcI0_Lin_Num],	
		sum(tel.[Count_RSCP_Lin]) as [RSCP_Lin_Den],	
		sum(tel.[Count_EcI0_Lin]) as [EcI0_Lin_Den],	
		
		-- Performance:
		-- Solo en DL:
		sum(0) as [3G_CQI],			sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,	sum(0) as CQI_U2100_Den,

		-- Ambos:
		sum(pfl.[HSPA_PCT]*pfl.[Count_HSPA]) as [HSPA_PCT_Num],
		sum(pfl.[HSPA+_PCT]*pfl.[Count_HSPA+]) as [HSPA+_PCT_Num],
		sum(pfl.[HSPA+_DC_PCT]*pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Num],
		sum(pfl.[Count_HSPA]) as [HSPA_PCT_Den],
		sum(pfl.[Count_HSPA+]) as [HSPA+_PCT_Den],
		sum(pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Den],

		sum(pfl.[UL_Inter_Lin]*pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Num],
		sum(pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Den],
	
		-- Performance LTE (no tienen sentido en 3GOnly):
		sum(0) as CQI_4G_Num,		sum(0) as CQI_L800_Num,		sum(0) as CQI_L1800_Num,		sum(0) as CQI_L2100_Num,		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,		sum(0) as CQI_L800_Den,		sum(0) as CQI_L1800_Den,		sum(0) as CQI_L2100_Den,		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,	sum(0) as LTE_10Mhz_SC_Use_Num,	sum(0) as LTE_15Mhz_SC_Use_Num,	sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,	sum(0) as LTE_20Mhz_CA_Use_Num,	sum(0) as LTE_25Mhz_CA_Use_Num,	sum(0) as LTE_30Mhz_CA_Use_Num,	sum(0) as LTE_35Mhz_CA_Use_Num,	sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,	sum(0) as LTE_10Mhz_SC_Use_Den,	sum(0) as LTE_15Mhz_SC_Use_Den,	sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,	sum(0) as LTE_20Mhz_CA_Use_Den,	sum(0) as LTE_25Mhz_CA_Use_Den,	sum(0) as LTE_30Mhz_CA_Use_Den,	sum(0) as LTE_35Mhz_CA_Use_Den,	sum(0) as LTE_40Mhz_CA_Use_Den,	

		sum(0) as LTE_BW_use_den,	sum(0) as [4G_RBs_use_Num],	sum(0) as [4G_RBs_use_Den],
	
		sum(0) as [4G_TM1_use_Num],			sum(0) as [4G_TM2_use_Num],			sum(0) as [4G_TM3_use_Num],		sum(0) as [4G_TM4_use_Num],		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],			sum(0) as [4G_TM7_use_Num],			sum(0) as [4G_TM8_use_Num],		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],	sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE(no tienen sentido en 3GOnly):
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs(no tienen sentido en 3GOnly):
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(isnull(O3G.[ 0-0.5Mbps_N ],0)) as [1_N],	sum(isnull(O3G.[ 0.5-1Mbps_N ],0)) as [2_N],	sum(isnull(O3G.[ 1-1.5Mbps_N ],0)) as [3_N],	sum(isnull(O3G.[ 1.5-2Mbps_N ],0)) as [4_N],	sum(isnull(O3G.[ 2-2.5Mbps_N ],0)) as [5_N],
		sum(isnull(O3G.[ 2.5-3Mbps_N ],0)) as [6_N],	sum(isnull(O3G.[ 3-3.5Mbps_N ],0)) as [7_N],	sum(isnull(O3G.[ 3.5-4Mbps_N ],0)) as [8_N],	sum(isnull(O3G.[ 4-4.5Mbps_N ],0)) as [9_N],	sum(isnull(O3G.[ 4.5-5Mbps_N ],0)) as [10_N],
		sum(isnull(O3G.[ 5-5.5Mbps_N ],0)) as [11_N],	sum(isnull(O3G.[ 5.5-6Mbps_N ],0)) as [12_N],	sum(isnull(O3G.[ 6-6.5Mbps_N ],0)) as [13_N],	sum(isnull(O3G.[ 6.5-7Mbps_N ],0)) as [14_N],	sum(isnull(O3G.[ 7-7.5Mbps_N ],0)) as [15_N],	
		sum(isnull(O3G.[ 7.5-8Mbps_N ],0)) as [16_N],	sum(isnull(O3G.[ 8-8.5Mbps_N ],0)) as [17_N],	sum(isnull(O3G.[ 8.5-9Mbps_N ],0)) as [18_N],	sum(isnull(O3G.[ 9-9.5Mbps_N ],0)) as [19_N],	sum(isnull(O3G.[ 9.5-10Mbps_N ],0)) as [20_N],
		sum(isnull(O3G.[ 10-10.5Mbps_N ],0)) as [21_N],	sum(isnull(O3G.[ 10.5-11Mbps_N ],0)) as [22_N],	sum(isnull(O3G.[ 11-11.5Mbps_N ],0)) as [23_N],	sum(isnull(O3G.[ 11.5-12Mbps_N ],0)) as [24_N],	sum(isnull(O3G.[ 12-12.5Mbps_N ],0)) as [25_N],
		sum(isnull(O3G.[ 12.5-13Mbps_N ],0)) as [26_N],	sum(isnull(O3G.[ 13-13.5Mbps_N ],0)) as [27_N],	sum(isnull(O3G.[ 13.5-14Mbps_N ],0)) as [28_N],	sum(isnull(O3G.[ 14-14.5Mbps_N ],0)) as [29_N],	sum(isnull(O3G.[ 14.5-15Mbps_N ],0)) as [30_N],
		sum(isnull(O3G.[ 15-15.5Mbps_N ],0)) as [31_N],	sum(isnull(O3G.[ 15.5-16Mbps_N ],0)) as [32_N],	sum(isnull(O3G.[ 16-16.5Mbps_N ],0)) as [33_N],	sum(isnull(O3G.[ 16.5-17Mbps_N ],0)) as [34_N],	sum(isnull(O3G.[ 17-17.5Mbps_N ],0)) as [35_N],
		sum(isnull(O3G.[ 17.5-18Mbps_N ],0)) as [36_N],	sum(isnull(O3G.[ 18-18.5Mbps_N ],0)) as [37_N],	sum(isnull(O3G.[ 18.5-19Mbps_N ],0)) as [38_N],	sum(isnull(O3G.[ 19-19.5Mbps_N ],0)) as [39_N],	sum(isnull(O3G.[ 19.5-20Mbps_N ],0)) as [40_N],
		sum(isnull(O3G.[ 20-20.5Mbps_N ],0)) as [41_N],	sum(isnull(O3G.[ 20.5-21Mbps_N ],0)) as [42_N],	sum(isnull(O3G.[ 21-21.5Mbps_N ],0)) as [43_N],	sum(isnull(O3G.[ 21.5-22Mbps_N ],0)) as [44_N],	sum(isnull(O3G.[ 22-22.5Mbps_N ],0)) as [45_N],
		sum(isnull(O3G.[ 22.5-23Mbps_N ],0)) as [46_N],	sum(isnull(O3G.[ 23-23.5Mbps_N ],0)) as [47_N],	sum(isnull(O3G.[ 23.5-24Mbps_N ],0)) as [48_N],	sum(isnull(O3G.[ 24-24.5Mbps_N ],0)) as [49_N],	sum(isnull(O3G.[ 24.5-25Mbps_N ],0)) as [50_N],
		sum(isnull(O3G.[ >25Mbps_N],0)) as [51_N],
		sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	
		sum(0) as [60_N],	sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(isnull(O3G.[ 0-5Mbps],0)) as [1]		,sum(isnull(O3G.[ 5-10Mbps],0)) as [2]		,sum(isnull(O3G.[ 10-15Mbps],0)) as [3]		,sum(isnull(O3G.[ 15-20Mbps],0)) as [4]		,sum(isnull(O3G.[ 20-25Mbps],0)) as [5]
		,sum(isnull(O3G.[ 25-30Mbps],0)) as [6]		,sum(isnull(O3G.[ 30-35Mbps],0)) as [7]		,sum(isnull(O3G.[ 35-40Mbps],0)) as [8]		,sum(isnull(O3G.[ 40-45Mbps],0)) as [9]		,sum(isnull(O3G.[ 45-50Mbps],0)) as [10]
		,sum(isnull(O3G.[ >50Mbps],0)) as [11]	
		,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]
		,sum(0) as [30]	,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]
		,sum(0) as [39]	,sum(0) as [40]	,sum(0) as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from	[AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_UL_Thput_CE] t
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_UL_Performance_CE_LTE_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_UL_Technology_CE_LTE_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_UL_Thput_CE_LTE_3G] O3G
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(O3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=O3G.mnc and t.Date_Reporting=O3G.Date_Reporting and t.entidad=O3G.entidad and t.Aggr_Type=O3G.Aggr_Type and t.Report_Type=O3G.Report_Type and t.meas_round=O3G.meas_round
				, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when  t.entidad like 'AVE-%' or  t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP
	
	-----------
	union all	-- Road 3GOnly - CE_UL
	select  
		p.codigo_ine, 'Roads' vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'Road 3GOnly' as meas_Tech, 'CE_UL' as Test_type, 'Uplink' as Direction,  t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
	
		-- General:
		sum(O3G.Subidas) as Num_tests,
		sum(O3G.[fallos de acceso]) as Failed,
		sum(O3G.[fallos de descarga]) as Dropped,
		sum(O3G.[SessionTime]*O3G.Subidas) as Session_time_Num,
		--sum(O3G.[Tiempo de subida]*O3G.count_throughput) as Session_time_Num,	-- SESSION_TIME de DL/UL, calculado como TRANSFER_TIME - se haría el cambio al calculo correcto en cambio de metodología para evitar salto de valor en QLIK.
		sum(O3G.count_throughput) as Throughput_Den,
		sum(O3G.Subidas) as Session_time_Den,
		--sum(O3G.count_throughput) as Session_time_Den,
		sum(O3G.Throughput*O3G.count_throughput) as Throughput_Num,
		max(O3G.[Throughput Max]) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(O3G.Count_Throughput_1M) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(O3G.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(O3G.Throughput_ALL*O3G.Count_Throughput_ALL) as Throughput_with_Error_Num,
		
		sum(0) as WEB_IP_ACCESS_TIME_NUM,			sum(0) as WEB_IP_ACCESS_TIME_DEN,	
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,	sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(tel.[% GSM]*tel.[Count_%GSM]) as Radio_2G_use_Num,
		sum(tel.[% WCDMA]*tel.[Count_%WCDMA]) as Radio_3G_use_Num,
		sum(tel.[% LTE]*tel.[Count_%LTE]) as Radio_4G_use_Num,
		sum(O3G.subidas*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(O3G.subidas*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,
		sum(tel.[Count_%U2100]) as Radio_U2100_use_Den,
		sum(tel.[Count_%U900]) as Radio_U900_use_Den,
		sum(tel.[Count_%LTE2100]) as Radio_LTE2100_use_Den,
		sum(tel.[Count_%LTE2600]) as Radio_LTE2600_use_Den,
		sum(tel.[Count_%LTE1800]) as Radio_LTE1800_use_Den,
		sum(tel.[Count_%LTE800]) as Radio_LTE800_use_Den,

		-- Solo en DL:
		sum(0) as [3G_DualCarrier_use_Num],		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],			sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],			sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],	sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],		sum(0) as [3G_16QAM_use_Num],	sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],		sum(0) as [3G_16QAM_use_Den],	sum(0) as [3G_64QAM_use_Den],

		-- Solo en UL:
		sum((tel.[% SF22]/100.0)*tel.[Count_%_SF22]) as [3G_%_SF22_Num],
		sum((tel.[% SF22andSF42]/100.0)*tel.[Count_%_SF22andSF42]) as [3G_%_SF22andSF42_Num],
		sum((tel.[% SF4]/100.0)*tel.[Count_%SF4]) as [3G_%_SF4_Num],
		sum((tel.[% SF42]/100.0)*tel.[Count_%_SF42]) as [3G_%_SF42_Num],
		sum(tel.[Count_%_SF22]) as [3G_%_SF22_Den],
		sum(tel.[Count_%_SF22andSF42]) as [3G_%_SF22andSF42_Den],
		sum(tel.[Count_%SF4]) as [3G_%_SF4_Den],
		sum(tel.[Count_%_SF42]) as [3G_%_SF42_Den],
		sum(tel.[% TTI 2ms_float]*tel.[Count_%TTI_2ms]) as [3G_%_TTI2ms_Num],
		sum(tel.[Count_%TTI_2ms]) as [3G_%_TTI2ms_Den],

		-- Ambos:
		sum(tel.[RSCP_Lin]*tel.[Count_RSCP_Lin]) as [RSCP_Lin_Num],
		sum(tel.[EcI0_Lin]*tel.[Count_EcI0_Lin]) as [EcI0_Lin_Num],	
		sum(tel.[Count_RSCP_Lin]) as [RSCP_Lin_Den],	
		sum(tel.[Count_EcI0_Lin]) as [EcI0_Lin_Den],	
		
		-- Performance:
		-- Solo en DL:
		sum(0) as [3G_CQI],			sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,	sum(0) as CQI_U2100_Den,

		-- Ambos:
		sum(pfl.[HSPA_PCT]*pfl.[Count_HSPA]) as [HSPA_PCT_Num],
		sum(pfl.[HSPA+_PCT]*pfl.[Count_HSPA+]) as [HSPA+_PCT_Num],
		sum(pfl.[HSPA+_DC_PCT]*pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Num],
		sum(pfl.[Count_HSPA]) as [HSPA_PCT_Den],
		sum(pfl.[Count_HSPA+]) as [HSPA+_PCT_Den],
		sum(pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Den],

		sum(pfl.[UL_Inter_Lin]*pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Num],
		sum(pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Den],
	
		-- Performance LTE (no tienen sentido en 3GOnly):
		sum(0) as CQI_4G_Num,		sum(0) as CQI_L800_Num,		sum(0) as CQI_L1800_Num,		sum(0) as CQI_L2100_Num,		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,		sum(0) as CQI_L800_Den,		sum(0) as CQI_L1800_Den,		sum(0) as CQI_L2100_Den,		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,	sum(0) as LTE_10Mhz_SC_Use_Num,	sum(0) as LTE_15Mhz_SC_Use_Num,	sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,	sum(0) as LTE_20Mhz_CA_Use_Num,	sum(0) as LTE_25Mhz_CA_Use_Num,	sum(0) as LTE_30Mhz_CA_Use_Num,	sum(0) as LTE_35Mhz_CA_Use_Num,	sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,	sum(0) as LTE_10Mhz_SC_Use_Den,	sum(0) as LTE_15Mhz_SC_Use_Den,	sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,	sum(0) as LTE_20Mhz_CA_Use_Den,	sum(0) as LTE_25Mhz_CA_Use_Den,	sum(0) as LTE_30Mhz_CA_Use_Den,	sum(0) as LTE_35Mhz_CA_Use_Den,	sum(0) as LTE_40Mhz_CA_Use_Den,	

		sum(0) as LTE_BW_use_den,	sum(0) as [4G_RBs_use_Num],	sum(0) as [4G_RBs_use_Den],
	
		sum(0) as [4G_TM1_use_Num],			sum(0) as [4G_TM2_use_Num],			sum(0) as [4G_TM3_use_Num],		sum(0) as [4G_TM4_use_Num],		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],			sum(0) as [4G_TM7_use_Num],			sum(0) as [4G_TM8_use_Num],		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],	sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE(no tienen sentido en 3GOnly):
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs(no tienen sentido en 3GOnly):
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(isnull(O3G.[ 0-0.5Mbps_N ],0)) as [1_N],	sum(isnull(O3G.[ 0.5-1Mbps_N ],0)) as [2_N],	sum(isnull(O3G.[ 1-1.5Mbps_N ],0)) as [3_N],	sum(isnull(O3G.[ 1.5-2Mbps_N ],0)) as [4_N],	sum(isnull(O3G.[ 2-2.5Mbps_N ],0)) as [5_N],
		sum(isnull(O3G.[ 2.5-3Mbps_N ],0)) as [6_N],	sum(isnull(O3G.[ 3-3.5Mbps_N ],0)) as [7_N],	sum(isnull(O3G.[ 3.5-4Mbps_N ],0)) as [8_N],	sum(isnull(O3G.[ 4-4.5Mbps_N ],0)) as [9_N],	sum(isnull(O3G.[ 4.5-5Mbps_N ],0)) as [10_N],
		sum(isnull(O3G.[ 5-5.5Mbps_N ],0)) as [11_N],	sum(isnull(O3G.[ 5.5-6Mbps_N ],0)) as [12_N],	sum(isnull(O3G.[ 6-6.5Mbps_N ],0)) as [13_N],	sum(isnull(O3G.[ 6.5-7Mbps_N ],0)) as [14_N],	sum(isnull(O3G.[ 7-7.5Mbps_N ],0)) as [15_N],	
		sum(isnull(O3G.[ 7.5-8Mbps_N ],0)) as [16_N],	sum(isnull(O3G.[ 8-8.5Mbps_N ],0)) as [17_N],	sum(isnull(O3G.[ 8.5-9Mbps_N ],0)) as [18_N],	sum(isnull(O3G.[ 9-9.5Mbps_N ],0)) as [19_N],	sum(isnull(O3G.[ 9.5-10Mbps_N ],0)) as [20_N],
		sum(isnull(O3G.[ 10-10.5Mbps_N ],0)) as [21_N],	sum(isnull(O3G.[ 10.5-11Mbps_N ],0)) as [22_N],	sum(isnull(O3G.[ 11-11.5Mbps_N ],0)) as [23_N],	sum(isnull(O3G.[ 11.5-12Mbps_N ],0)) as [24_N],	sum(isnull(O3G.[ 12-12.5Mbps_N ],0)) as [25_N],
		sum(isnull(O3G.[ 12.5-13Mbps_N ],0)) as [26_N],	sum(isnull(O3G.[ 13-13.5Mbps_N ],0)) as [27_N],	sum(isnull(O3G.[ 13.5-14Mbps_N ],0)) as [28_N],	sum(isnull(O3G.[ 14-14.5Mbps_N ],0)) as [29_N],	sum(isnull(O3G.[ 14.5-15Mbps_N ],0)) as [30_N],
		sum(isnull(O3G.[ 15-15.5Mbps_N ],0)) as [31_N],	sum(isnull(O3G.[ 15.5-16Mbps_N ],0)) as [32_N],	sum(isnull(O3G.[ 16-16.5Mbps_N ],0)) as [33_N],	sum(isnull(O3G.[ 16.5-17Mbps_N ],0)) as [34_N],	sum(isnull(O3G.[ 17-17.5Mbps_N ],0)) as [35_N],
		sum(isnull(O3G.[ 17.5-18Mbps_N ],0)) as [36_N],	sum(isnull(O3G.[ 18-18.5Mbps_N ],0)) as [37_N],	sum(isnull(O3G.[ 18.5-19Mbps_N ],0)) as [38_N],	sum(isnull(O3G.[ 19-19.5Mbps_N ],0)) as [39_N],	sum(isnull(O3G.[ 19.5-20Mbps_N ],0)) as [40_N],
		sum(isnull(O3G.[ 20-20.5Mbps_N ],0)) as [41_N],	sum(isnull(O3G.[ 20.5-21Mbps_N ],0)) as [42_N],	sum(isnull(O3G.[ 21-21.5Mbps_N ],0)) as [43_N],	sum(isnull(O3G.[ 21.5-22Mbps_N ],0)) as [44_N],	sum(isnull(O3G.[ 22-22.5Mbps_N ],0)) as [45_N],
		sum(isnull(O3G.[ 22.5-23Mbps_N ],0)) as [46_N],	sum(isnull(O3G.[ 23-23.5Mbps_N ],0)) as [47_N],	sum(isnull(O3G.[ 23.5-24Mbps_N ],0)) as [48_N],	sum(isnull(O3G.[ 24-24.5Mbps_N ],0)) as [49_N],	sum(isnull(O3G.[ 24.5-25Mbps_N ],0)) as [50_N],
		sum(isnull(O3G.[ >25Mbps_N],0)) as [51_N],
		sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],	
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--t.Region_VF as Region_Road_VF, t.Region_OSP as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(isnull(O3G.[ 0-5Mbps],0)) as [1]		,sum(isnull(O3G.[ 5-10Mbps],0)) as [2]		,sum(isnull(O3G.[ 10-15Mbps],0)) as [3]		,sum(isnull(O3G.[ 15-20Mbps],0)) as [4]		,sum(isnull(O3G.[ 20-25Mbps],0)) as [5]
		,sum(isnull(O3G.[ 25-30Mbps],0)) as [6]		,sum(isnull(O3G.[ 30-35Mbps],0)) as [7]		,sum(isnull(O3G.[ 35-40Mbps],0)) as [8]		,sum(isnull(O3G.[ 40-45Mbps],0)) as [9]		,sum(isnull(O3G.[ 45-50Mbps],0)) as [10]
		,sum(isnull(O3G.[ >50Mbps],0)) as [11]	
		,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]
		,sum(0) as [30]	,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]
		,sum(0) as [39]	,sum(0) as [40]	,sum(0) as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from	[aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_UL_Thput_CE] t
				left outer join [aggrData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_UL_Performance_CE_LTE_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round
				left outer join [aggrData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_UL_Technology_CE_LTE_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round
				left outer join [AGGRData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_UL_Thput_CE_LTE_3G] O3G
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(O3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=O3G.mnc and t.Date_Reporting=O3G.Date_Reporting and t.entidad=O3G.entidad and t.Aggr_Type=O3G.Aggr_Type and t.Report_Type=O3G.Report_Type and t.meas_round=O3G.meas_round
				, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP

	-----------
	-- 3GOnly_4G y ROAD - NC_DL
	insert into _RI_Data_e 
	select  
		p.codigo_ine, case when  t.entidad like 'AVE-%' or  t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'3GOnly_4G' as meas_Tech, 'NC_DL' as Test_type, 'Downlink' as Direction,  t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
	
		-- General:
		sum(O3G.navegaciones) as Num_tests,
		sum(O3G.[fallos de acceso]) as Failed,
		sum(O3G.[fallos de descarga]) as Dropped,
		sum(0) as Session_time_Num,
		sum(O3G.count_throughput) as Throughput_Den,
		sum(0) as Session_time_Den,
		sum(O3G.Throughput*O3G.count_throughput) as Throughput_Num,
		max(O3G.[Throughput Max]) as Throughput_Max,
		sum(O3G.Count_Throughput_3M) as Throughput_3M_Num,
		sum(O3G.Count_Throughput_1M) as Throughput_1M_Num,
		sum(O3G.Count_Throughput_128k) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(O3G.Count_Throughput_384k) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(O3G.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(O3G.Throughput_ALL*O3G.Count_Throughput_ALL) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(tel.[% GSM]*tel.[Count_%GSM]) as Radio_2G_use_Num,
		sum(tel.[% WCDMA]*tel.[Count_%WCDMA]) as Radio_3G_use_Num,
		sum(tel.[% LTE]*tel.[Count_%LTE]) as Radio_4G_use_Num,
		sum(O3G.navegaciones*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(O3G.navegaciones*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,
		sum(tel.[Count_%U2100]) as Radio_U2100_use_Den,
		sum(tel.[Count_%U900]) as Radio_U900_use_Den,
		sum(tel.[Count_%LTE2100]) as Radio_LTE2100_use_Den,
		sum(tel.[Count_%LTE2600]) as Radio_LTE2600_use_Den,
		sum(tel.[Count_%LTE1800]) as Radio_LTE1800_use_Den,
		sum(tel.[Count_%LTE800]) as Radio_LTE800_use_Den,

		-- Solo en DL:
		sum(tel.[% Dual Carrier]*tel.[Count_Dual_Carrier]) as [3G_DualCarrier_use_Num],	sum(tel.[Count_Dual_Carrier]) as [3G_DualCarrier_use_Den],
		sum(tel.[%DC_U2100]*tel.[Count_DC_U2100]) as [3G_DC_2100_use_Num],				sum(tel.[Count_DC_U2100]) as [3G_DC_2100_use_Den],
		sum(tel.[%DC_U900]*tel.[Count_DC_U900]) as [3G_DC_900_use_Num],					sum(tel.[Count_DC_U900]) as [3G_DC_900_use_Den],

		sum(tel.[Num Codes]*tel.[Count_Num_Codes]) as [3G_NumCodes_use_Num],
		sum(tel.[Count_Num_Codes]) as [3G_NumCodes_use_Den],

		sum(tel.[QPSK]*tel.[Count_QPSK]) as [3G_QPSK_use_Num],
		sum(tel.[16QAM]*tel.[Count_16QAM]) as [3G_16QAM_use_Num],
		sum(tel.[64QAM]*tel.[Count_64QAM]) as [3G_64QAM_use_Num],
		sum(tel.[Count_QPSK]) as [3G_QPSK_use_Den],
		sum(tel.[Count_16QAM]) as [3G_16QAM_use_Den],
		sum(tel.[Count_64QAM]) as [3G_64QAM_use_Den],

		-- Solo en UL:
		sum(0) as [3G_%_SF22_Num],		sum(0) as [3G_%_SF22andSF42_Num],	sum(0) as [3G_%_SF4_Num],	sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],		sum(0) as [3G_%_SF22andSF42_Den],	sum(0) as [3G_%_SF4_Den],	sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],	sum(0) as [3G_%_TTI2ms_Den],

		-- Ambos:
		sum(tel.[RSCP_Lin]*tel.[Count_RSCP_Lin]) as [RSCP_Lin_Num],
		sum(tel.[EcI0_Lin]*tel.[Count_EcI0_Lin]) as [EcI0_Lin_Num],	
		sum(tel.[Count_RSCP_Lin]) as [RSCP_Lin_Den],	
		sum(tel.[Count_EcI0_Lin]) as [EcI0_Lin_Den],	

		-- Performance:
		sum(pfl.CQI*(isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) [3G_CQI],
		sum((isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) as [3G_DataStats_Den],
		Sum(pfl.CQI_U900*isnull(pfl.count_cqi_u900,0)) as CQI_U900_Num,
		sum(isnull(pfl.count_cqi_u900,0)) as CQI_U900_Den,
		Sum(pfl.CQI_U2100*isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Num,
		sum(isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Den,

		sum(pfl.[HSPA_PCT]*pfl.[Count_HSPA]) as [HSPA_PCT_Num],
		sum(pfl.[HSPA+_PCT]*pfl.[Count_HSPA+]) as [HSPA+_PCT_Num],
		sum(pfl.[HSPA+_DC_PCT]*pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Num],
		sum(pfl.[Count_HSPA]) as [HSPA_PCT_Den],
		sum(pfl.[Count_HSPA+]) as [HSPA+_PCT_Den],
		sum(pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Den],

		sum(pfl.[UL_Inter_Lin]*pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Num],
		sum(pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Den],	
	
		-- Performance LTE (no tienen sentido en 3GOnly):
		sum(0) as CQI_4G_Num,		sum(0) as CQI_L800_Num,		sum(0) as CQI_L1800_Num,		sum(0) as CQI_L2100_Num,		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,		sum(0) as CQI_L800_Den,		sum(0) as CQI_L1800_Den,		sum(0) as CQI_L2100_Den,		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,	sum(0) as LTE_10Mhz_SC_Use_Num,	sum(0) as LTE_15Mhz_SC_Use_Num,	sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,	sum(0) as LTE_20Mhz_CA_Use_Num,	sum(0) as LTE_25Mhz_CA_Use_Num,	sum(0) as LTE_30Mhz_CA_Use_Num,	sum(0) as LTE_35Mhz_CA_Use_Num,	sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,	sum(0) as LTE_10Mhz_SC_Use_Den,	sum(0) as LTE_15Mhz_SC_Use_Den,	sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,	sum(0) as LTE_20Mhz_CA_Use_Den,	sum(0) as LTE_25Mhz_CA_Use_Den,	sum(0) as LTE_30Mhz_CA_Use_Den,	sum(0) as LTE_35Mhz_CA_Use_Den,	sum(0) as LTE_40Mhz_CA_Use_Den,	

		sum(0) as LTE_BW_use_den,	sum(0) as [4G_RBs_use_Num],	sum(0) as [4G_RBs_use_Den],
	
		sum(0) as [4G_TM1_use_Num],			sum(0) as [4G_TM2_use_Num],			sum(0) as [4G_TM3_use_Num],		sum(0) as [4G_TM4_use_Num],		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],			sum(0) as [4G_TM7_use_Num],			sum(0) as [4G_TM8_use_Num],		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],	sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE(no tienen sentido en 3GOnly):
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs(no tienen sentido en 3GOnly):
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(isnull(O3G.[ 0-3.5Mbps_N ],0)) as [1_N],		sum(isnull(O3G.[ 3.5-7Mbps_N ],0)) as [2_N],		sum(isnull(O3G.[ 7-10.5Mbps_N ],0)) as [3_N],		sum(isnull(O3G.[ 10.5-14Mbps_N ],0)) as [4_N],		sum(isnull(O3G.[ 14-17.5Mbps_N ],0)) as [5_N],
		sum(isnull(O3G.[ 17.5-21Mbps_N ],0)) as [6_N],		sum(isnull(O3G.[ 21-24.5Mbps_N ],0)) as [7_N],		sum(isnull(O3G.[ 24.5-28Mbps_N ],0)) as [8_N],		sum(isnull(O3G.[ 28-31.5Mbps_N ],0)) as [9_N],		sum(isnull(O3G.[ 31.5-35Mbps_N ],0)) as [10_N],
		sum(isnull(O3G.[ 35-38.5Mbps_N ],0)) as [11_N],		sum(isnull(O3G.[ 38.5-42Mbps_N ],0)) as [12_N],		sum(isnull(O3G.[ 42-45.5Mbps_N ],0)) as [13_N],		sum(isnull(O3G.[ 45.5-49Mbps_N ],0)) as [14_N],	sum(isnull(O3G.[ 49-52.5Mbps_N ],0)) as [15_N],
		sum(isnull(O3G.[ 52.5-56Mbps_N ],0)) as [16_N],		sum(isnull(O3G.[ 56-59.5Mbps_N ],0)) as [17_N],		sum(isnull(O3G.[ 59.5-63Mbps_N ],0)) as [18_N],		sum(isnull(O3G.[ 63-66.5Mbps_N ],0)) as [19_N],	sum(isnull(O3G.[ 66.5-70Mbps_N ],0)) as [20_N],
		sum(isnull(O3G.[ 70-73.5Mbps_N ],0)) as [21_N],		sum(isnull(O3G.[ 73.5-77Mbps_N ],0)) as [22_N],		sum(isnull(O3G.[ 77-80.5Mbps_N ],0)) as [23_N],		sum(isnull(O3G.[ 80.5-84Mbps_N ],0)) as [24_N],	sum(isnull(O3G.[ 84-87.5Mbps_N ],0)) as [25_N],
		sum(isnull(O3G.[ 87.5-91Mbps_N ],0)) as [26_N],		sum(isnull(O3G.[ 91-94.5Mbps_N ],0)) as [27_N],		sum(isnull(O3G.[ 94.5-98Mbps_N ],0)) as [28_N],		sum(isnull(O3G.[ 98-101.5Mbps_N ],0)) as [29_N],	sum(isnull(O3G.[ 101.5-105Mbps_N ],0)) as [30_N],
		sum(isnull(O3G.[ 105-108.5Mbps_N ],0)) as [31_N],	sum(isnull(O3G.[ 108.5-112Mbps_N ],0)) as [32_N],	sum(isnull(O3G.[ 112-115.5Mbps_N ],0)) as [33_N],	sum(isnull(O3G.[ 115.5-119Mbps_N ],0)) as [34_N],	sum(isnull(O3G.[ 119-122.5Mbps_N ],0)) as [35_N],
		sum(isnull(O3G.[ 122.5-126Mbps_N ],0)) as [36_N],	sum(isnull(O3G.[ 126-129.5Mbps_N ],0)) as [37_N],	sum(isnull(O3G.[ 129.5-133Mbps_N ],0)) as [38_N],	sum(isnull(O3G.[ 133-136.5Mbps_N ],0)) as [39_N],	sum(isnull(O3G.[ 136.5-140Mbps_N ],0)) as [40_N],
		sum(isnull(O3G.[ 140-143.5Mbps_N ],0)) as [41_N],	sum(isnull(O3G.[ 143.5-147Mbps_N ],0)) as [42_N],	sum(isnull(O3G.[ 147-150.5Mbps_N ],0)) as [43_N],	sum(isnull(O3G.[ 150.5-154Mbps_N ],0)) as [44_N],	sum(isnull(O3G.[ 154-157.5Mbps_N ],0)) as [45_N],
		sum(isnull(O3G.[ 157.5-161Mbps_N ],0)) as [46_N],	sum(isnull(O3G.[ 161-164.5Mbps_N ],0)) as [47_N],	sum(isnull(O3G.[ 164.5-168Mbps_N ],0)) as [48_N],	sum(isnull(O3G.[ 168-171.5Mbps_N ],0)) as [49_N],	sum(isnull(O3G.[ 171.5-175Mbps_N ],0)) as [50_N],
		sum(isnull(O3G.[ 175-178.5Mbps_N ],0)) as [51_N],	sum(isnull(O3G.[ 178.5-182Mbps_N ],0)) as [52_N],	sum(isnull(O3G.[ 182-185.5Mbps_N ],0)) as [53_N],	sum(isnull(O3G.[ 185.5-189Mbps_N ],0)) as [54_N],	sum(isnull(O3G.[ 189-192.5Mbps_N ],0)) as [55_N],
		sum(isnull(O3G.[ 192.5-196Mbps_N ],0)) as [56_N],	sum(isnull(O3G.[ >196Mbps_N ],0)) as [57_N],
		sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],	sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(isnull(O3G.[ 0-5Mbps],0)) as [1]		,sum(isnull(O3G.[ 5-10Mbps],0)) as [2]		,sum(isnull(O3G.[ 10-15Mbps],0)) as [3]		,sum(isnull(O3G.[ 15-20Mbps],0)) as [4]		,sum(isnull(O3G.[ 20-25Mbps],0)) as [5]
		,sum(isnull(O3G.[ 25-30Mbps],0)) as [6]		,sum(isnull(O3G.[ 30-35Mbps],0)) as [7]		,sum(isnull(O3G.[ 35-40Mbps],0)) as [8]		,sum(isnull(O3G.[ 40-45Mbps],0)) as [9]		,sum(isnull(O3G.[ 45-50Mbps],0)) as [10]
		,sum(isnull(O3G.[ 50-55Mbps],0)) as [11]	,sum(isnull(O3G.[ 55-60Mbps],0)) as [12]	,sum(isnull(O3G.[ 60-65Mbps],0)) as [13]	,sum(isnull(O3G.[ 65-70Mbps],0)) as [14]	,sum(isnull(O3G.[ 70-75Mbps],0)) as [15]
		,sum(isnull(O3G.[ 75-80Mbps],0)) as [16]	,sum(isnull(O3G.[ 80-85Mbps],0)) as [17]	,sum(isnull(O3G.[ 85-90Mbps],0)) as [18]	,sum(isnull(O3G.[ 90-95Mbps],0)) as [19]	,sum(isnull(O3G.[ 95-100Mbps],0)) as [20]
		,sum(isnull(O3G.[ 100-105Mbps],0)) as [21]	,sum(isnull(O3G.[ 105-110Mbps],0)) as [22]	,sum(isnull(O3G.[ 110-115Mbps],0)) as [23]	,sum(isnull(O3G.[ 115-120Mbps],0)) as [24]	,sum(isnull(O3G.[ 120-125Mbps],0)) as [25]
		,sum(isnull(O3G.[ 125-130Mbps],0)) as [26]	,sum(isnull(O3G.[ 130-135Mbps],0)) as [27]	,sum(isnull(O3G.[ 135-140Mbps],0)) as [28]	,sum(isnull(O3G.[ 140-145Mbps],0)) as [29]	,sum(isnull(O3G.[ 145-150Mbps],0)) as [30]
		,sum(isnull(O3G.[ >150Mbps],0)) as [31]
		,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]	,sum(0) as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from	[AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_DL_Thput_NC] t
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_DL_Performance_NC_LTE_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_DL_Technology_NC_LTE_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_DL_Thput_NC_LTE_3G] O3G
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(O3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=O3G.mnc and t.Date_Reporting=O3G.Date_Reporting and t.entidad=O3G.entidad and t.Aggr_Type=O3G.Aggr_Type and t.Report_Type=O3G.Report_Type and t.meas_round=O3G.meas_round
				, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when  t.entidad like 'AVE-%' or  t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP

	-----------
	union all	-- Road 3GOnly - NC_DL
	select  
		p.codigo_ine, 'Roads' vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'Road 3GOnly' as meas_Tech, 'NC_DL' as Test_type, 'Downlink' as Direction,  t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
	
		-- General:
		sum(O3G.navegaciones) as Num_tests,
		sum(O3G.[fallos de acceso]) as Failed,
		sum(O3G.[fallos de descarga]) as Dropped,
		sum(0) as Session_time_Num,
		sum(O3G.count_throughput) as Throughput_Den,
		sum(0) as Session_time_Den,
		sum(O3G.Throughput*O3G.count_throughput) as Throughput_Num,
		max(O3G.[Throughput Max]) as Throughput_Max,
		sum(O3G.Count_Throughput_3M) as Throughput_3M_Num,
		sum(O3G.Count_Throughput_1M) as Throughput_1M_Num,
		sum(O3G.Count_Throughput_128k) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(O3G.Count_Throughput_384k) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(O3G.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(O3G.Throughput_ALL*O3G.Count_Throughput_ALL) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(tel.[% GSM]*tel.[Count_%GSM]) as Radio_2G_use_Num,
		sum(tel.[% WCDMA]*tel.[Count_%WCDMA]) as Radio_3G_use_Num,
		sum(tel.[% LTE]*tel.[Count_%LTE]) as Radio_4G_use_Num,
		sum(O3G.navegaciones*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(O3G.navegaciones*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,
		sum(tel.[Count_%U2100]) as Radio_U2100_use_Den,
		sum(tel.[Count_%U900]) as Radio_U900_use_Den,
		sum(tel.[Count_%LTE2100]) as Radio_LTE2100_use_Den,
		sum(tel.[Count_%LTE2600]) as Radio_LTE2600_use_Den,
		sum(tel.[Count_%LTE1800]) as Radio_LTE1800_use_Den,
		sum(tel.[Count_%LTE800]) as Radio_LTE800_use_Den,

		-- Solo en DL:
		sum(tel.[% Dual Carrier]*tel.[Count_Dual_Carrier]) as [3G_DualCarrier_use_Num],	sum(tel.[Count_Dual_Carrier]) as [3G_DualCarrier_use_Den],
		sum(tel.[%DC_U2100]*tel.[Count_DC_U2100]) as [3G_DC_2100_use_Num],				sum(tel.[Count_DC_U2100]) as [3G_DC_2100_use_Den],
		sum(tel.[%DC_U900]*tel.[Count_DC_U900]) as [3G_DC_900_use_Num],					sum(tel.[Count_DC_U900]) as [3G_DC_900_use_Den],

		sum(tel.[Num Codes]*tel.[Count_Num_Codes]) as [3G_NumCodes_use_Num],
		sum(tel.[Count_Num_Codes]) as [3G_NumCodes_use_Den],

		sum(tel.[QPSK]*tel.[Count_QPSK]) as [3G_QPSK_use_Num],
		sum(tel.[16QAM]*tel.[Count_16QAM]) as [3G_16QAM_use_Num],
		sum(tel.[64QAM]*tel.[Count_64QAM]) as [3G_64QAM_use_Num],
		sum(tel.[Count_QPSK]) as [3G_QPSK_use_Den],
		sum(tel.[Count_16QAM]) as [3G_16QAM_use_Den],
		sum(tel.[Count_64QAM]) as [3G_64QAM_use_Den],

		-- Solo en UL:
		sum(0) as [3G_%_SF22_Num],		sum(0) as [3G_%_SF22andSF42_Num],	sum(0) as [3G_%_SF4_Num],	sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],		sum(0) as [3G_%_SF22andSF42_Den],	sum(0) as [3G_%_SF4_Den],	sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],	sum(0) as [3G_%_TTI2ms_Den],

		-- Ambos:
		sum(tel.[RSCP_Lin]*tel.[Count_RSCP_Lin]) as [RSCP_Lin_Num],
		sum(tel.[EcI0_Lin]*tel.[Count_EcI0_Lin]) as [EcI0_Lin_Num],	
		sum(tel.[Count_RSCP_Lin]) as [RSCP_Lin_Den],	
		sum(tel.[Count_EcI0_Lin]) as [EcI0_Lin_Den],	

		-- Performance:
		sum(pfl.CQI*(isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) [3G_CQI],
		sum((isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) as [3G_DataStats_Den],
		Sum(pfl.CQI_U900*isnull(pfl.count_cqi_u900,0)) as CQI_U900_Num,
		sum(isnull(pfl.count_cqi_u900,0)) as CQI_U900_Den,
		Sum(pfl.CQI_U2100*isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Num,
		sum(isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Den,

		sum(pfl.[HSPA_PCT]*pfl.[Count_HSPA]) as [HSPA_PCT_Num],
		sum(pfl.[HSPA+_PCT]*pfl.[Count_HSPA+]) as [HSPA+_PCT_Num],
		sum(pfl.[HSPA+_DC_PCT]*pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Num],
		sum(pfl.[Count_HSPA]) as [HSPA_PCT_Den],
		sum(pfl.[Count_HSPA+]) as [HSPA+_PCT_Den],
		sum(pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Den],

		sum(pfl.[UL_Inter_Lin]*pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Num],
		sum(pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Den],	
	
		-- Performance LTE (no tienen sentido en 3GOnly):
		sum(0) as CQI_4G_Num,		sum(0) as CQI_L800_Num,		sum(0) as CQI_L1800_Num,		sum(0) as CQI_L2100_Num,		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,		sum(0) as CQI_L800_Den,		sum(0) as CQI_L1800_Den,		sum(0) as CQI_L2100_Den,		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,	sum(0) as LTE_10Mhz_SC_Use_Num,	sum(0) as LTE_15Mhz_SC_Use_Num,	sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,	sum(0) as LTE_20Mhz_CA_Use_Num,	sum(0) as LTE_25Mhz_CA_Use_Num,	sum(0) as LTE_30Mhz_CA_Use_Num,	sum(0) as LTE_35Mhz_CA_Use_Num,	sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,	sum(0) as LTE_10Mhz_SC_Use_Den,	sum(0) as LTE_15Mhz_SC_Use_Den,	sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,	sum(0) as LTE_20Mhz_CA_Use_Den,	sum(0) as LTE_25Mhz_CA_Use_Den,	sum(0) as LTE_30Mhz_CA_Use_Den,	sum(0) as LTE_35Mhz_CA_Use_Den,	sum(0) as LTE_40Mhz_CA_Use_Den,	

		sum(0) as LTE_BW_use_den,	sum(0) as [4G_RBs_use_Num],	sum(0) as [4G_RBs_use_Den],
	
		sum(0) as [4G_TM1_use_Num],			sum(0) as [4G_TM2_use_Num],			sum(0) as [4G_TM3_use_Num],		sum(0) as [4G_TM4_use_Num],		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],			sum(0) as [4G_TM7_use_Num],			sum(0) as [4G_TM8_use_Num],		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],	sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE(no tienen sentido en 3GOnly):
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs(no tienen sentido en 3GOnly):
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(isnull(O3G.[ 0-3.5Mbps_N ],0)) as [1_N],		sum(isnull(O3G.[ 3.5-7Mbps_N ],0)) as [2_N],		sum(isnull(O3G.[ 7-10.5Mbps_N ],0)) as [3_N],		sum(isnull(O3G.[ 10.5-14Mbps_N ],0)) as [4_N],		sum(isnull(O3G.[ 14-17.5Mbps_N ],0)) as [5_N],
		sum(isnull(O3G.[ 17.5-21Mbps_N ],0)) as [6_N],		sum(isnull(O3G.[ 21-24.5Mbps_N ],0)) as [7_N],		sum(isnull(O3G.[ 24.5-28Mbps_N ],0)) as [8_N],		sum(isnull(O3G.[ 28-31.5Mbps_N ],0)) as [9_N],		sum(isnull(O3G.[ 31.5-35Mbps_N ],0)) as [10_N],
		sum(isnull(O3G.[ 35-38.5Mbps_N ],0)) as [11_N],		sum(isnull(O3G.[ 38.5-42Mbps_N ],0)) as [12_N],		sum(isnull(O3G.[ 42-45.5Mbps_N ],0)) as [13_N],		sum(isnull(O3G.[ 45.5-49Mbps_N ],0)) as [14_N],		sum(isnull(O3G.[ 49-52.5Mbps_N ],0)) as [15_N],
		sum(isnull(O3G.[ 52.5-56Mbps_N ],0)) as [16_N],		sum(isnull(O3G.[ 56-59.5Mbps_N ],0)) as [17_N],		sum(isnull(O3G.[ 59.5-63Mbps_N ],0)) as [18_N],		sum(isnull(O3G.[ 63-66.5Mbps_N ],0)) as [19_N],		sum(isnull(O3G.[ 66.5-70Mbps_N ],0)) as [20_N],
		sum(isnull(O3G.[ 70-73.5Mbps_N ],0)) as [21_N],		sum(isnull(O3G.[ 73.5-77Mbps_N ],0)) as [22_N],		sum(isnull(O3G.[ 77-80.5Mbps_N ],0)) as [23_N],		sum(isnull(O3G.[ 80.5-84Mbps_N ],0)) as [24_N],		sum(isnull(O3G.[ 84-87.5Mbps_N ],0)) as [25_N],
		sum(isnull(O3G.[ 87.5-91Mbps_N ],0)) as [26_N],		sum(isnull(O3G.[ 91-94.5Mbps_N ],0)) as [27_N],		sum(isnull(O3G.[ 94.5-98Mbps_N ],0)) as [28_N],		sum(isnull(O3G.[ 98-101.5Mbps_N ],0)) as [29_N],	sum(isnull(O3G.[ 101.5-105Mbps_N ],0)) as [30_N],
		sum(isnull(O3G.[ 105-108.5Mbps_N ],0)) as [31_N],	sum(isnull(O3G.[ 108.5-112Mbps_N ],0)) as [32_N],	sum(isnull(O3G.[ 112-115.5Mbps_N ],0)) as [33_N],	sum(isnull(O3G.[ 115.5-119Mbps_N ],0)) as [34_N],	sum(isnull(O3G.[ 119-122.5Mbps_N ],0)) as [35_N],
		sum(isnull(O3G.[ 122.5-126Mbps_N ],0)) as [36_N],	sum(isnull(O3G.[ 126-129.5Mbps_N ],0)) as [37_N],	sum(isnull(O3G.[ 129.5-133Mbps_N ],0)) as [38_N],	sum(isnull(O3G.[ 133-136.5Mbps_N ],0)) as [39_N],	sum(isnull(O3G.[ 136.5-140Mbps_N ],0)) as [40_N],
		sum(isnull(O3G.[ 140-143.5Mbps_N ],0)) as [41_N],	sum(isnull(O3G.[ 143.5-147Mbps_N ],0)) as [42_N],	sum(isnull(O3G.[ 147-150.5Mbps_N ],0)) as [43_N],	sum(isnull(O3G.[ 150.5-154Mbps_N ],0)) as [44_N],	sum(isnull(O3G.[ 154-157.5Mbps_N ],0)) as [45_N],
		sum(isnull(O3G.[ 157.5-161Mbps_N ],0)) as [46_N],	sum(isnull(O3G.[ 161-164.5Mbps_N ],0)) as [47_N],	sum(isnull(O3G.[ 164.5-168Mbps_N ],0)) as [48_N],	sum(isnull(O3G.[ 168-171.5Mbps_N ],0)) as [49_N],	sum(isnull(O3G.[ 171.5-175Mbps_N ],0)) as [50_N],
		sum(isnull(O3G.[ 175-178.5Mbps_N ],0)) as [51_N],	sum(isnull(O3G.[ 178.5-182Mbps_N ],0)) as [52_N],	sum(isnull(O3G.[ 182-185.5Mbps_N ],0)) as [53_N],	sum(isnull(O3G.[ 185.5-189Mbps_N ],0)) as [54_N],	sum(isnull(O3G.[ 189-192.5Mbps_N ],0)) as [55_N],
		sum(isnull(O3G.[ 192.5-196Mbps_N ],0)) as [56_N],	sum(isnull(O3G.[ >196Mbps_N ],0)) as [57_N],
		sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],	sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--t.Region_VF as Region_Road_VF, t.Region_OSP as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(isnull(O3G.[ 0-5Mbps],0)) as [1]		,sum(isnull(O3G.[ 5-10Mbps],0)) as [2]		,sum(isnull(O3G.[ 10-15Mbps],0)) as [3]		,sum(isnull(O3G.[ 15-20Mbps],0)) as [4]		,sum(isnull(O3G.[ 20-25Mbps],0)) as [5]
		,sum(isnull(O3G.[ 25-30Mbps],0)) as [6]		,sum(isnull(O3G.[ 30-35Mbps],0)) as [7]		,sum(isnull(O3G.[ 35-40Mbps],0)) as [8]		,sum(isnull(O3G.[ 40-45Mbps],0)) as [9]		,sum(isnull(O3G.[ 45-50Mbps],0)) as [10]
		,sum(isnull(O3G.[ 50-55Mbps],0)) as [11]	,sum(isnull(O3G.[ 55-60Mbps],0)) as [12]	,sum(isnull(O3G.[ 60-65Mbps],0)) as [13]	,sum(isnull(O3G.[ 65-70Mbps],0)) as [14]	,sum(isnull(O3G.[ 70-75Mbps],0)) as [15]
		,sum(isnull(O3G.[ 75-80Mbps],0)) as [16]	,sum(isnull(O3G.[ 80-85Mbps],0)) as [17]	,sum(isnull(O3G.[ 85-90Mbps],0)) as [18]	,sum(isnull(O3G.[ 90-95Mbps],0)) as [19]	,sum(isnull(O3G.[ 95-100Mbps],0)) as [20]
		,sum(isnull(O3G.[ 100-105Mbps],0)) as [21]	,sum(isnull(O3G.[ 105-110Mbps],0)) as [22]	,sum(isnull(O3G.[ 110-115Mbps],0)) as [23]	,sum(isnull(O3G.[ 115-120Mbps],0)) as [24]	,sum(isnull(O3G.[ 120-125Mbps],0)) as [25]
		,sum(isnull(O3G.[ 125-130Mbps],0)) as [26]	,sum(isnull(O3G.[ 130-135Mbps],0)) as [27]	,sum(isnull(O3G.[ 135-140Mbps],0)) as [28]	,sum(isnull(O3G.[ 140-145Mbps],0)) as [29]	,sum(isnull(O3G.[ 145-150Mbps],0)) as [30]
		,sum(isnull(O3G.[ >150Mbps],0)) as [31]
		,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]	,sum(0) as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from	[aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_DL_Thput_NC] t
				left outer join [aggrData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_DL_Performance_NC_LTE_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round
				left outer join [aggrData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_DL_Technology_NC_LTE_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round
				left outer join [AGGRData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_DL_Thput_NC_LTE_3G] O3G
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(O3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=O3G.mnc and t.Date_Reporting=O3G.Date_Reporting and t.entidad=O3G.entidad and t.Aggr_Type=O3G.Aggr_Type and t.Report_Type=O3G.Report_Type and t.meas_round=O3G.meas_round
				, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP

	-----------
	-- 3GOnly_4G y ROAD - NC_UL
	insert into _RI_Data_e 
	select  
		p.codigo_ine, case when  t.entidad like 'AVE-%' or  t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'3GOnly_4G' as meas_Tech, 'NC_UL' as Test_type, 'Uplink' as Direction,  t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
	
		-- General:
		sum(O3G.Subidas) as Num_tests,
		sum(O3G.[fallos de acceso]) as Failed,
		sum(O3G.[fallos de descarga]) as Dropped,
		sum(0) as Session_time_Num,
		sum(O3G.count_throughput) as Throughput_Den,
		sum(0) as Session_time_Den,
		sum(O3G.Throughput*O3G.count_throughput) as Throughput_Num,
		max(O3G.[Throughput Max]) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(O3G.Count_Throughput_1M) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(O3G.Count_Throughput_64k) as Throughput_64K_Num,
		sum(O3G.Count_Throughput_384k) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(O3G.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(O3G.Throughput_ALL*O3G.Count_Throughput_ALL) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(tel.[% GSM]*tel.[Count_%GSM]) as Radio_2G_use_Num,
		sum(tel.[% WCDMA]*tel.[Count_%WCDMA]) as Radio_3G_use_Num,
		sum(tel.[% LTE]*tel.[Count_%LTE]) as Radio_4G_use_Num,
		sum(O3G.Subidas*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(O3G.Subidas*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,
		sum(tel.[Count_%U2100]) as Radio_U2100_use_Den,
		sum(tel.[Count_%U900]) as Radio_U900_use_Den,
		sum(tel.[Count_%LTE2100]) as Radio_LTE2100_use_Den,
		sum(tel.[Count_%LTE2600]) as Radio_LTE2600_use_Den,
		sum(tel.[Count_%LTE1800]) as Radio_LTE1800_use_Den,
		sum(tel.[Count_%LTE800]) as Radio_LTE800_use_Den,

		-- Solo en DL:
		sum(0) as [3G_DualCarrier_use_Num],		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],			sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],			sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],	sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],		sum(0) as [3G_16QAM_use_Num],	sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],		sum(0) as [3G_16QAM_use_Den],	sum(0) as [3G_64QAM_use_Den],

		-- Solo en UL:
		sum((tel.[% SF22]/100.0)*tel.[Count_%_SF22]) as [3G_%_SF22_Num],
		sum((tel.[% SF22andSF42]/100.0)*tel.[Count_%_SF22andSF42]) as [3G_%_SF22andSF42_Num],
		sum((tel.[% SF4]/100.0)*tel.[Count_%SF4]) as [3G_%_SF4_Num],
		sum((tel.[% SF42]/100.0)*tel.[Count_%_SF42]) as [3G_%_SF42_Num],
		sum(tel.[Count_%_SF22]) as [3G_%_SF22_Den],
		sum(tel.[Count_%_SF22andSF42]) as [3G_%_SF22andSF42_Den],
		sum(tel.[Count_%SF4]) as [3G_%_SF4_Den],
		sum(tel.[Count_%_SF42]) as [3G_%_SF42_Den],
		sum(tel.[% TTI 2ms_float]*tel.[Count_%TTI_2ms]) as [3G_%_TTI2ms_Num],
		sum(tel.[Count_%TTI_2ms]) as [3G_%_TTI2ms_Den],

		-- Ambos:
		sum(tel.[RSCP_Lin]*tel.[Count_RSCP_Lin]) as [RSCP_Lin_Num],
		sum(tel.[EcI0_Lin]*tel.[Count_EcI0_Lin]) as [EcI0_Lin_Num],	
		sum(tel.[Count_RSCP_Lin]) as [RSCP_Lin_Den],	
		sum(tel.[Count_EcI0_Lin]) as [EcI0_Lin_Den],	
		
		-- Performance:
		-- Solo en DL:
		sum(0) as [3G_CQI],			sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,	sum(0) as CQI_U2100_Den,

		-- Ambos:
		sum(pfl.[HSPA_PCT]*pfl.[Count_HSPA]) as [HSPA_PCT_Num],
		sum(pfl.[HSPA+_PCT]*pfl.[Count_HSPA+]) as [HSPA+_PCT_Num],
		sum(pfl.[HSPA+_DC_PCT]*pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Num],
		sum(pfl.[Count_HSPA]) as [HSPA_PCT_Den],
		sum(pfl.[Count_HSPA+]) as [HSPA+_PCT_Den],
		sum(pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Den],

		sum(pfl.[UL_Inter_Lin]*pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Num],
		sum(pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Den],
	
		-- Performance LTE (no tienen sentido en 3GOnly):
		sum(0) as CQI_4G_Num,		sum(0) as CQI_L800_Num,		sum(0) as CQI_L1800_Num,		sum(0) as CQI_L2100_Num,		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,		sum(0) as CQI_L800_Den,		sum(0) as CQI_L1800_Den,		sum(0) as CQI_L2100_Den,		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,	sum(0) as LTE_10Mhz_SC_Use_Num,	sum(0) as LTE_15Mhz_SC_Use_Num,	sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,	sum(0) as LTE_20Mhz_CA_Use_Num,	sum(0) as LTE_25Mhz_CA_Use_Num,	sum(0) as LTE_30Mhz_CA_Use_Num,	sum(0) as LTE_35Mhz_CA_Use_Num,	sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,	sum(0) as LTE_10Mhz_SC_Use_Den,	sum(0) as LTE_15Mhz_SC_Use_Den,	sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,	sum(0) as LTE_20Mhz_CA_Use_Den,	sum(0) as LTE_25Mhz_CA_Use_Den,	sum(0) as LTE_30Mhz_CA_Use_Den,	sum(0) as LTE_35Mhz_CA_Use_Den,	sum(0) as LTE_40Mhz_CA_Use_Den,	

		sum(0) as LTE_BW_use_den,	sum(0) as [4G_RBs_use_Num],	sum(0) as [4G_RBs_use_Den],
	
		sum(0) as [4G_TM1_use_Num],			sum(0) as [4G_TM2_use_Num],			sum(0) as [4G_TM3_use_Num],		sum(0) as [4G_TM4_use_Num],		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],			sum(0) as [4G_TM7_use_Num],			sum(0) as [4G_TM8_use_Num],		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],	sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE(no tienen sentido en 3GOnly):
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs(no tienen sentido en 3GOnly):
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(isnull(O3G.[ 0-0.8Mbps_N ],0)) as [1_N],	sum(isnull(O3G.[ 0.8-1.6Mbps_N ],0)) as [2_N],		sum(isnull(O3G.[ 1.6-2.4Mbps_N ],0)) as [3_N],		sum(isnull(O3G.[ 2.4-3.2Mbps_N ],0)) as [4_N],		sum(isnull(O3G.[ 3.2-4Mbps_N ],0)) as [5_N],
		sum(isnull(O3G.[ 4-4.8Mbps_N ],0)) as [6_N],	sum(isnull(O3G.[ 4.8-5.6Mbps_N ],0)) as [7_N],		sum(isnull(O3G.[ 5.6-6.4Mbps_N ],0)) as [8_N],		sum(isnull(O3G.[ 6.4-7.2Mbps_N ],0)) as [9_N],		sum(isnull(O3G.[ 7.2-8Mbps_N ],0)) as [10_N],
		sum(isnull(O3G.[ 8-8.8Mbps_N ],0)) as [11_N],	sum(isnull(O3G.[ 8.8-9.6Mbps_N ],0)) as [12_N],		sum(isnull(O3G.[ 9.6-10.4Mbps_N ],0)) as [13_N],	sum(isnull(O3G.[ 10.4-11.2Mbps_N ],0)) as [14_N],	sum(isnull(O3G.[ 11.2-12Mbps_N ],0)) as [15_N],
		sum(isnull(O3G.[ 12-12.8Mbps_N ],0)) as [16_N],	sum(isnull(O3G.[ 12.8-13.6Mbps_N ],0)) as [17_N],	sum(isnull(O3G.[ 13.6-14.4Mbps_N ],0)) as [18_N],	sum(isnull(O3G.[ 14.4-15.2Mbps_N ],0)) as [19_N],	sum(isnull(O3G.[ 15.2-16Mbps_N ],0)) as [20_N],
		sum(isnull(O3G.[ 16-16.8Mbps_N ],0)) as [21_N],	sum(isnull(O3G.[ 16.8-17.6Mbps_N ],0)) as [22_N],	sum(isnull(O3G.[ 17.6-18.4Mbps_N ],0)) as [23_N],	sum(isnull(O3G.[ 18.4-19.2Mbps_N ],0)) as [24_N],	sum(isnull(O3G.[ 19.2-20Mbps_N ],0)) as [25_N],
		sum(isnull(O3G.[ 20-20.8Mbps_N ],0)) as [26_N],	sum(isnull(O3G.[ 20.8-21.6Mbps_N ],0)) as [27_N],	sum(isnull(O3G.[ 21.6-22.4Mbps_N ],0)) as [28_N],	sum(isnull(O3G.[ 22.4-23.2Mbps_N ],0)) as [29_N],	sum(isnull(O3G.[ 23.2-24Mbps_N ],0)) as [30_N],
		sum(isnull(O3G.[ 24-24.8Mbps_N ],0)) as [31_N],	sum(isnull(O3G.[ 24.8-25.6Mbps_N ],0)) as [32_N],	sum(isnull(O3G.[ 25.6-26.4Mbps_N ],0)) as [33_N],	sum(isnull(O3G.[ 26.4-27.2Mbps_N ],0)) as [34_N],	sum(isnull(O3G.[ 27.2-28Mbps_N ],0)) as [35_N],
		sum(isnull(O3G.[ 28-28.8Mbps_N ],0)) as [36_N],	sum(isnull(O3G.[ 28.8-29.6Mbps_N ],0)) as [37_N],	sum(isnull(O3G.[ 29.6-30.4Mbps_N ],0)) as [38_N],	sum(isnull(O3G.[ 30.4-31.2Mbps_N ],0)) as [39_N],	sum(isnull(O3G.[ 31.2-32Mbps_N ],0)) as [40_N],
		sum(isnull(O3G.[ 32-32.8Mbps_N ],0)) as [41_N],	sum(isnull(O3G.[ 32.8-33.6Mbps_N ],0)) as [42_N],	sum(isnull(O3G.[ 33.6-34.4Mbps_N ],0)) as [43_N],	sum(isnull(O3G.[ 34.4-35.2Mbps_N ],0)) as [44_N],	sum(isnull(O3G.[ 35.2-36Mbps_N ],0)) as [45_N],
		sum(isnull(O3G.[ 36-36.8Mbps_N ],0)) as [46_N],	sum(isnull(O3G.[ 36.8-37.6Mbps_N ],0)) as [47_N],	sum(isnull(O3G.[ 37.6-38.4Mbps_N ],0)) as [48_N],	sum(isnull(O3G.[ 38.4-39.2Mbps_N ],0)) as [49_N],	sum(isnull(O3G.[ 39.2-40Mbps_N ],0)) as [50_N],
		sum(isnull(O3G.[ 40-40.8Mbps_N ],0)) as [51_N],	sum(isnull(O3G.[ 40.8-41.6Mbps_N ],0)) as [52_N],	sum(isnull(O3G.[ 41.6-42.4Mbps_N ],0)) as [53_N],	sum(isnull(O3G.[ 42.4-43.2Mbps_N ],0)) as [54_N],	sum(isnull(O3G.[ 43.2-44Mbps_N ],0)) as [55_N],
		sum(isnull(O3G.[ 44-44.8Mbps_N ],0)) as [56_N],	sum(isnull(O3G.[ 44.8-45.6Mbps_N ],0)) as [57_N],	sum(isnull(O3G.[ 45.6-46.4Mbps_N ],0)) as [58_N],	sum(isnull(O3G.[ 46.4-47.2Mbps_N ],0)) as [59_N],	sum(isnull(O3G.[ 47.2-48Mbps_N ],0)) as [60_N],
		sum(isnull(O3G.[ 48-48.8Mbps_N ],0)) as [61_N],	sum(isnull(O3G.[ 48.8-49.6Mbps_N ],0)) as [62_N],	sum(isnull(O3G.[ 49.6-50.4Mbps_N ],0)) as [63_N],	sum(isnull(O3G.[ 50.4-51.2Mbps_N ],0)) as [64_N],	sum(isnull(O3G.[ 51.2-52Mbps_N ],0)) as [65_N],	
		sum(isnull(O3G.[ >52Mbps_N],0)) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(isnull(O3G.[ 0-5Mbps],0)) as [1]		,sum(isnull(O3G.[ 5-10Mbps],0)) as [2]		,sum(isnull(O3G.[ 10-15Mbps],0)) as [3]		,sum(isnull(O3G.[ 15-20Mbps],0)) as [4]		,sum(isnull(O3G.[ 20-25Mbps],0)) as [5]
		,sum(isnull(O3G.[ 25-30Mbps],0)) as [6]		,sum(isnull(O3G.[ 30-35Mbps],0)) as [7]		,sum(isnull(O3G.[ 35-40Mbps],0)) as [8]		,sum(isnull(O3G.[ 40-45Mbps],0)) as [9]		,sum(isnull(O3G.[ 45-50Mbps],0)) as [10]
		,sum(isnull(O3G.[ >50Mbps],0)) as [11]	
		,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]
		,sum(0) as [30]	,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]
		,sum(0) as [39]	,sum(0) as [40]	,sum(0) as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from	[AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_UL_Thput_NC] t
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_UL_Performance_NC_LTE_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_UL_Technology_NC_LTE_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round
				left outer join [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_UL_Thput_NC_LTE_3G] O3G
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(O3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=O3G.mnc and t.Date_Reporting=O3G.Date_Reporting and t.entidad=O3G.entidad and t.Aggr_Type=O3G.Aggr_Type and t.Report_Type=O3G.Report_Type and t.meas_round=O3G.meas_round
				, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when  t.entidad like 'AVE-%' or  t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP

	-----------
	union all	-- Road 3GOnly - NC_UL	
	select  
		p.codigo_ine, 'Roads' vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'Road 3GOnly' as meas_Tech, 'NC_UL' as Test_type, 'Uplink' as Direction,  t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
	
		-- General:
		sum(O3G.Subidas) as Num_tests,
		sum(O3G.[fallos de acceso]) as Failed,
		sum(O3G.[fallos de descarga]) as Dropped,
		sum(0) as Session_time_Num,
		sum(O3G.count_throughput) as Throughput_Den,
		sum(0) as Session_time_Den,
		sum(O3G.Throughput*O3G.count_throughput) as Throughput_Num,
		max(O3G.[Throughput Max]) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(O3G.Count_Throughput_1M) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(O3G.Count_Throughput_64k) as Throughput_64K_Num,
		sum(O3G.Count_Throughput_384k) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(O3G.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(O3G.Throughput_ALL*O3G.Count_Throughput_ALL) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(tel.[% GSM]*tel.[Count_%GSM]) as Radio_2G_use_Num,
		sum(tel.[% WCDMA]*tel.[Count_%WCDMA]) as Radio_3G_use_Num,
		sum(tel.[% LTE]*tel.[Count_%LTE]) as Radio_4G_use_Num,
		sum(O3G.Subidas*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(O3G.Subidas*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,
		sum(tel.[Count_%U2100]) as Radio_U2100_use_Den,
		sum(tel.[Count_%U900]) as Radio_U900_use_Den,
		sum(tel.[Count_%LTE2100]) as Radio_LTE2100_use_Den,
		sum(tel.[Count_%LTE2600]) as Radio_LTE2600_use_Den,
		sum(tel.[Count_%LTE1800]) as Radio_LTE1800_use_Den,
		sum(tel.[Count_%LTE800]) as Radio_LTE800_use_Den,

		-- Solo en DL:
		sum(0) as [3G_DualCarrier_use_Num],		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],			sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],			sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],	sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],		sum(0) as [3G_16QAM_use_Num],	sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],		sum(0) as [3G_16QAM_use_Den],	sum(0) as [3G_64QAM_use_Den],

		-- Solo en UL:
		sum((tel.[% SF22]/100.0)*tel.[Count_%_SF22]) as [3G_%_SF22_Num],
		sum((tel.[% SF22andSF42]/100.0)*tel.[Count_%_SF22andSF42]) as [3G_%_SF22andSF42_Num],
		sum((tel.[% SF4]/100.0)*tel.[Count_%SF4]) as [3G_%_SF4_Num],
		sum((tel.[% SF42]/100.0)*tel.[Count_%_SF42]) as [3G_%_SF42_Num],
		sum(tel.[Count_%_SF22]) as [3G_%_SF22_Den],
		sum(tel.[Count_%_SF22andSF42]) as [3G_%_SF22andSF42_Den],
		sum(tel.[Count_%SF4]) as [3G_%_SF4_Den],
		sum(tel.[Count_%_SF42]) as [3G_%_SF42_Den],
		sum(tel.[% TTI 2ms_float]*tel.[Count_%TTI_2ms]) as [3G_%_TTI2ms_Num],
		sum(tel.[Count_%TTI_2ms]) as [3G_%_TTI2ms_Den],

		-- Ambos:
		sum(tel.[RSCP_Lin]*tel.[Count_RSCP_Lin]) as [RSCP_Lin_Num],
		sum(tel.[EcI0_Lin]*tel.[Count_EcI0_Lin]) as [EcI0_Lin_Num],	
		sum(tel.[Count_RSCP_Lin]) as [RSCP_Lin_Den],	
		sum(tel.[Count_EcI0_Lin]) as [EcI0_Lin_Den],	
		
		-- Performance:
		-- Solo en DL:
		sum(0) as [3G_CQI],			sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,	sum(0) as CQI_U2100_Den,

		-- Ambos:
		sum(pfl.[HSPA_PCT]*pfl.[Count_HSPA]) as [HSPA_PCT_Num],
		sum(pfl.[HSPA+_PCT]*pfl.[Count_HSPA+]) as [HSPA+_PCT_Num],
		sum(pfl.[HSPA+_DC_PCT]*pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Num],
		sum(pfl.[Count_HSPA]) as [HSPA_PCT_Den],
		sum(pfl.[Count_HSPA+]) as [HSPA+_PCT_Den],
		sum(pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Den],

		sum(pfl.[UL_Inter_Lin]*pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Num],
		sum(pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Den],
	
		-- Performance LTE (no tienen sentido en 3GOnly):
		sum(0) as CQI_4G_Num,		sum(0) as CQI_L800_Num,		sum(0) as CQI_L1800_Num,		sum(0) as CQI_L2100_Num,		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,		sum(0) as CQI_L800_Den,		sum(0) as CQI_L1800_Den,		sum(0) as CQI_L2100_Den,		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,	sum(0) as LTE_10Mhz_SC_Use_Num,	sum(0) as LTE_15Mhz_SC_Use_Num,	sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,	sum(0) as LTE_20Mhz_CA_Use_Num,	sum(0) as LTE_25Mhz_CA_Use_Num,	sum(0) as LTE_30Mhz_CA_Use_Num,	sum(0) as LTE_35Mhz_CA_Use_Num,	sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,	sum(0) as LTE_10Mhz_SC_Use_Den,	sum(0) as LTE_15Mhz_SC_Use_Den,	sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,	sum(0) as LTE_20Mhz_CA_Use_Den,	sum(0) as LTE_25Mhz_CA_Use_Den,	sum(0) as LTE_30Mhz_CA_Use_Den,	sum(0) as LTE_35Mhz_CA_Use_Den,	sum(0) as LTE_40Mhz_CA_Use_Den,	

		sum(0) as LTE_BW_use_den,	sum(0) as [4G_RBs_use_Num],	sum(0) as [4G_RBs_use_Den],
	
		sum(0) as [4G_TM1_use_Num],			sum(0) as [4G_TM2_use_Num],			sum(0) as [4G_TM3_use_Num],		sum(0) as [4G_TM4_use_Num],		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],			sum(0) as [4G_TM7_use_Num],			sum(0) as [4G_TM8_use_Num],		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],	sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE(no tienen sentido en 3GOnly):
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs(no tienen sentido en 3GOnly):
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(isnull(O3G.[ 0-0.8Mbps_N ],0)) as [1_N],	sum(isnull(O3G.[ 0.8-1.6Mbps_N ],0)) as [2_N],		sum(isnull(O3G.[ 1.6-2.4Mbps_N ],0)) as [3_N],		sum(isnull(O3G.[ 2.4-3.2Mbps_N ],0)) as [4_N],		sum(isnull(O3G.[ 3.2-4Mbps_N ],0)) as [5_N],
		sum(isnull(O3G.[ 4-4.8Mbps_N ],0)) as [6_N],	sum(isnull(O3G.[ 4.8-5.6Mbps_N ],0)) as [7_N],		sum(isnull(O3G.[ 5.6-6.4Mbps_N ],0)) as [8_N],		sum(isnull(O3G.[ 6.4-7.2Mbps_N ],0)) as [9_N],		sum(isnull(O3G.[ 7.2-8Mbps_N ],0)) as [10_N],
		sum(isnull(O3G.[ 8-8.8Mbps_N ],0)) as [11_N],	sum(isnull(O3G.[ 8.8-9.6Mbps_N ],0)) as [12_N],		sum(isnull(O3G.[ 9.6-10.4Mbps_N ],0)) as [13_N],	sum(isnull(O3G.[ 10.4-11.2Mbps_N ],0)) as [14_N],	sum(isnull(O3G.[ 11.2-12Mbps_N ],0)) as [15_N],
		sum(isnull(O3G.[ 12-12.8Mbps_N ],0)) as [16_N],	sum(isnull(O3G.[ 12.8-13.6Mbps_N ],0)) as [17_N],	sum(isnull(O3G.[ 13.6-14.4Mbps_N ],0)) as [18_N],	sum(isnull(O3G.[ 14.4-15.2Mbps_N ],0)) as [19_N],	sum(isnull(O3G.[ 15.2-16Mbps_N ],0)) as [20_N],
		sum(isnull(O3G.[ 16-16.8Mbps_N ],0)) as [21_N],	sum(isnull(O3G.[ 16.8-17.6Mbps_N ],0)) as [22_N],	sum(isnull(O3G.[ 17.6-18.4Mbps_N ],0)) as [23_N],	sum(isnull(O3G.[ 18.4-19.2Mbps_N ],0)) as [24_N],	sum(isnull(O3G.[ 19.2-20Mbps_N ],0)) as [25_N],
		sum(isnull(O3G.[ 20-20.8Mbps_N ],0)) as [26_N],	sum(isnull(O3G.[ 20.8-21.6Mbps_N ],0)) as [27_N],	sum(isnull(O3G.[ 21.6-22.4Mbps_N ],0)) as [28_N],	sum(isnull(O3G.[ 22.4-23.2Mbps_N ],0)) as [29_N],	sum(isnull(O3G.[ 23.2-24Mbps_N ],0)) as [30_N],
		sum(isnull(O3G.[ 24-24.8Mbps_N ],0)) as [31_N],	sum(isnull(O3G.[ 24.8-25.6Mbps_N ],0)) as [32_N],	sum(isnull(O3G.[ 25.6-26.4Mbps_N ],0)) as [33_N],	sum(isnull(O3G.[ 26.4-27.2Mbps_N ],0)) as [34_N],	sum(isnull(O3G.[ 27.2-28Mbps_N ],0)) as [35_N],
		sum(isnull(O3G.[ 28-28.8Mbps_N ],0)) as [36_N],	sum(isnull(O3G.[ 28.8-29.6Mbps_N ],0)) as [37_N],	sum(isnull(O3G.[ 29.6-30.4Mbps_N ],0)) as [38_N],	sum(isnull(O3G.[ 30.4-31.2Mbps_N ],0)) as [39_N],	sum(isnull(O3G.[ 31.2-32Mbps_N ],0)) as [40_N],
		sum(isnull(O3G.[ 32-32.8Mbps_N ],0)) as [41_N],	sum(isnull(O3G.[ 32.8-33.6Mbps_N ],0)) as [42_N],	sum(isnull(O3G.[ 33.6-34.4Mbps_N ],0)) as [43_N],	sum(isnull(O3G.[ 34.4-35.2Mbps_N ],0)) as [44_N],	sum(isnull(O3G.[ 35.2-36Mbps_N ],0)) as [45_N],
		sum(isnull(O3G.[ 36-36.8Mbps_N ],0)) as [46_N],	sum(isnull(O3G.[ 36.8-37.6Mbps_N ],0)) as [47_N],	sum(isnull(O3G.[ 37.6-38.4Mbps_N ],0)) as [48_N],	sum(isnull(O3G.[ 38.4-39.2Mbps_N ],0)) as [49_N],	sum(isnull(O3G.[ 39.2-40Mbps_N ],0)) as [50_N],
		sum(isnull(O3G.[ 40-40.8Mbps_N ],0)) as [51_N],	sum(isnull(O3G.[ 40.8-41.6Mbps_N ],0)) as [52_N],	sum(isnull(O3G.[ 41.6-42.4Mbps_N ],0)) as [53_N],	sum(isnull(O3G.[ 42.4-43.2Mbps_N ],0)) as [54_N],	sum(isnull(O3G.[ 43.2-44Mbps_N ],0)) as [55_N],
		sum(isnull(O3G.[ 44-44.8Mbps_N ],0)) as [56_N],	sum(isnull(O3G.[ 44.8-45.6Mbps_N ],0)) as [57_N],	sum(isnull(O3G.[ 45.6-46.4Mbps_N ],0)) as [58_N],	sum(isnull(O3G.[ 46.4-47.2Mbps_N ],0)) as [59_N],	sum(isnull(O3G.[ 47.2-48Mbps_N ],0)) as [60_N],
		sum(isnull(O3G.[ 48-48.8Mbps_N ],0)) as [61_N],	sum(isnull(O3G.[ 48.8-49.6Mbps_N ],0)) as [62_N],	sum(isnull(O3G.[ 49.6-50.4Mbps_N ],0)) as [63_N],	sum(isnull(O3G.[ 50.4-51.2Mbps_N ],0)) as [64_N],	sum(isnull(O3G.[ 51.2-52Mbps_N ],0)) as [65_N],	
		sum(isnull(O3G.[ >52Mbps_N],0)) as [66_N]
	
		--t.Region_VF as Region_Road_VF, t.Region_OSP as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(isnull(O3G.[ 0-5Mbps],0)) as [1]		,sum(isnull(O3G.[ 5-10Mbps],0)) as [2]		,sum(isnull(O3G.[ 10-15Mbps],0)) as [3]		,sum(isnull(O3G.[ 15-20Mbps],0)) as [4]		,sum(isnull(O3G.[ 20-25Mbps],0)) as [5]
		,sum(isnull(O3G.[ 25-30Mbps],0)) as [6]		,sum(isnull(O3G.[ 30-35Mbps],0)) as [7]		,sum(isnull(O3G.[ 35-40Mbps],0)) as [8]		,sum(isnull(O3G.[ 40-45Mbps],0)) as [9]		,sum(isnull(O3G.[ 45-50Mbps],0)) as [10]
		,sum(isnull(O3G.[ >50Mbps],0)) as [11]	
		,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]
		,sum(0) as [30]	,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]
		,sum(0) as [39]	,sum(0) as [40]	,sum(0) as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL
		
	from	[aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_UL_Thput_NC] t
				left outer join [aggrData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_UL_Performance_NC_LTE_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round
				left outer join [aggrData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_UL_Technology_NC_LTE_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round
				left outer join [AGGRData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_UL_Thput_NC_LTE_3G] O3G
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(O3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=O3G.mnc and t.Date_Reporting=O3G.Date_Reporting and t.entidad=O3G.entidad and t.Aggr_Type=O3G.Aggr_Type and t.Report_Type=O3G.Report_Type and t.meas_round=O3G.meas_round
				, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP

	-------------
	-- 3GOnly_4G y ROAD WEB	
	insert into _RI_Data_e	
	select  
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'3GOnly_4G' as meas_Tech, 'WEB HTTP' as Test_type, 'Downlink' as Direction, t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
		
		-- General:
		sum(W3G.Navegaciones) as Num_tests,
		sum(W3G.[Fallos de acceso]) as Failed,
		sum(W3G.[Navegaciones fallidas]) as Dropped,
		sum(cast(W3G.[Session Time] as float)*W3G.[Count_SessionTime]) as Session_time_Num,
		sum(0) as Throughput_Den,
		sum(W3G.[Count_SessionTime]) as Session_time_Den,
		sum(0) as Throughput_Num,
		max(0) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(0) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(0) as Throughput_with_Error_Den,
		sum(0) as Throughput_with_Error_Num,
		sum(cast(W3G.[IP Service Setup Time] as float)*W3G.[Count_IPServiceSetupTime]) as WEB_IP_ACCESS_TIME_NUM,
		sum(W3G.[Count_IPServiceSetupTime]) as WEB_IP_ACCESS_TIME_DEN,
		sum(cast(W3G.[Transfer Time] as float)*W3G.[Count_TransferTime]) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(W3G.[Count_TransferTime]) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(0) as Radio_2G_use_Num,
		sum(0) as Radio_3G_use_Num,
		sum(0) as Radio_4G_use_Num,
		sum(0) as Radio_use_Den,
		sum(0) as Radio_2G_use_Den,
		sum(0) as Radio_3G_use_Den,
		sum(0) as Radio_4G_use_Den,

		sum(0) as Radio_U2100_use_Num,
		sum(0) as Radio_U900_use_Num,
		sum(0) as Radio_LTE2100_use_Num,
		sum(0) as Radio_LTE2600_use_Num,
		sum(0) as Radio_LTE1800_use_Num,
		sum(0) as Radio_LTE800_use_Num,
		sum(0) as Radio_Band_Use_Den,
		sum(0) as Radio_U2100_use_Den,
		sum(0) as Radio_U900_use_Den,
		sum(0) as Radio_LTE2100_use_Den,
		sum(0) as Radio_LTE2600_use_Den,
		sum(0) as Radio_LTE1800_use_Den,
		sum(0) as Radio_LTE800_use_Den,

		sum(0) as [3G_DualCarrier_use_Num],
		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],
		sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],
		sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],
		sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],
		sum(0) as [3G_16QAM_use_Num],
		sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],
		sum(0) as [3G_16QAM_use_Den],
		sum(0) as [3G_64QAM_use_Den],

		sum(0) as [3G_%_SF22_Num],
		sum(0) as [3G_%_SF22andSF42_Num],
		sum(0) as [3G_%_SF4_Num],
		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],
		sum(0) as [3G_%_SF22andSF42_Den],
		sum(0) as [3G_%_SF4_Den],
		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],
		sum(0) as [3G_%_TTI2ms_Den],	
	
		sum(0) as [RSCP_Lin_Num],
		sum(0) as [EcI0_Lin_Num],	
		sum(0) as [RSCP_Lin_Den],	
		sum(0) as [EcI0_Lin_Den],
	
		-- Performance:
		sum(0) as [3G_CQI],
		sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,
		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,
		sum(0) as CQI_U2100_Den,

		sum(0) as [HSPA_PCT_Num],
		sum(0) as [HSPA+_PCT_Num],
		sum(0) as [HSPA+_DC_PCT_Num],
		sum(0) as [HSPA_PCT_Den],
		sum(0) as [HSPA+_PCT_Den],
		sum(0) as [HSPA+_DC_PCT_Den],

		sum(0) as [UL_Inter_Lin_Num],
		sum(0) as [UL_Inter_Lin_Den],	
	
		-- Performance LTE:
		sum(0) as CQI_4G_Num,
		sum(0) as CQI_L800_Num,
		sum(0) as CQI_L1800_Num,
		sum(0) as CQI_L2100_Num,
		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,
		sum(0) as CQI_L800_Den,
		sum(0) as CQI_L1800_Den,
		sum(0) as CQI_L2100_Den,
		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,
		sum(0) as LTE_10Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_SC_Use_Num,
		sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,
		sum(0) as LTE_20Mhz_CA_Use_Num,
		sum(0) as LTE_25Mhz_CA_Use_Num,
		sum(0) as LTE_30Mhz_CA_Use_Num,
		sum(0) as LTE_35Mhz_CA_Use_Num,
		sum(0) as LTE_40Mhz_CA_Use_Num,
		sum(0) as LTE_5Mhz_SC_Use_Den,
		sum(0) as LTE_10Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_SC_Use_Den,
		sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,
		sum(0) as LTE_20Mhz_CA_Use_Den,
		sum(0) as LTE_25Mhz_CA_Use_Den,
		sum(0) as LTE_30Mhz_CA_Use_Den,
		sum(0) as LTE_35Mhz_CA_Use_Den,
		sum(0) as LTE_40Mhz_CA_Use_Den,
		
		sum(0) as LTE_BW_use_den,	
		sum(0) as [4G_RBs_use_Num],
		sum(0) as [4G_RBs_use_Den],

		sum(0) as [4G_TM1_use_Num],
		sum(0) as [4G_TM2_use_Num],
		sum(0) as [4G_TM3_use_Num],
		sum(0) as [4G_TM4_use_Num],
		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],
		sum(0) as [4G_TM7_use_Num],
		sum(0) as [4G_TM8_use_Num],
		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],
		sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],
	
		-- Technology LTE:
		sum(0) as [4G_%CA_Num],
		sum(0) as [4G_%CA_Den],
		sum(0) as [4G_BPSK_Use_Num],
		sum(0) as [4G_QPSK_Use_Num],
		sum(0) as [4G_16QAM_Use_Num],
		sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],
		sum(0) as [4G_QPSK_Use_Den],
		sum(0) as [4G_16QAM_Use_Den],
		sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],
		sum(0) as [RSRP_Lin_Num],
		sum(0) as [RSRQ_Lin_Num],
		sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],
		sum(0) as [RSRQ_Lin_Den],
		sum(0) as [SINR_Lin_Den],		

		--New KPIs:
		sum(0) as [MIMO_num],
		sum(0) as [RI1_num],
		sum(0) as [RI2_num],
		sum(0) as [MIMO_den],
		sum(0) as [RI1_den],
		sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,
		sum(0) as RBs_Allocated_Num,
		max(0) as RBs_Allocated_Max,	
	
		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(0) as [1_N],	sum(0) as [2_N],	sum(0) as [3_N],	sum(0) as [4_N],	sum(0) as [5_N],	sum(0) as [6_N],	sum(0) as [7_N],	sum(0) as [8_N],	sum(0) as [9_N],	sum(0) as [10_N],
		sum(0) as [11_N],	sum(0) as [12_N],	sum(0) as [13_N],	sum(0) as [14_N],	sum(0) as [15_N],	sum(0) as [16_N],	sum(0) as [17_N],	sum(0) as [18_N],	sum(0) as [19_N],	sum(0) as [20_N],
		sum(0) as [21_N],	sum(0) as [22_N],	sum(0) as [23_N],	sum(0) as [24_N],	sum(0) as [25_N],	sum(0) as [26_N],	sum(0) as [27_N],	sum(0) as [28_N],	sum(0) as [29_N],	sum(0) as [30_N],
		sum(0) as [31_N],	sum(0) as [32_N],	sum(0) as [33_N],	sum(0) as [34_N],	sum(0) as [35_N],	sum(0) as [36_N],	sum(0) as [37_N],	sum(0) as [38_N],	sum(0) as [39_N],	sum(0) as [40_N],
		sum(0) as [41_N],	sum(0) as [42_N],	sum(0) as [43_N],	sum(0) as [44_N],	sum(0) as [45_N],	sum(0) as [46_N],	sum(0) as [47_N],	sum(0) as [48_N],	sum(0) as [49_N],	sum(0) as [50_N],
		sum(0) as [51_N],	sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(0) as [1]	,sum(0) as [2]	,sum(0) as [3]	,sum(0) as [4]	,sum(0) as [5]	,sum(0) as [6]	,sum(0) as [7]	,sum(0) as [8]	,sum(0) as [9]	,sum(0) as [10]
		,sum(0) as [11]	,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]	,sum(0) as [30]
		,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]
		,sum(0) as [41],

		-- Parametros de configuracion:
		t.ASideDevice as ASideDevice, t.BSideDevice as BSideDevice, t.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Web] t
		left outer join [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Web_3G] W3G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(W3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=W3G.mnc and t.Date_Reporting=W3G.Date_Reporting and t.entidad=W3G.entidad and t.Aggr_Type=W3G.Aggr_Type and t.Report_Type=W3G.Report_Type and t.meas_round=W3G.meas_round)
		, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		t.ASideDevice, t.BSideDevice, t.SWVersion--, t.Region_VF, t.Region_OSP

	-----------
	union all	-- WEB Road 3GOnly
	select  
		p.codigo_ine, 'Roads' vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'Road 3GOnly' as meas_Tech, 'WEB HTTP' as Test_type, 'Downlink' as Direction, t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
		
		-- General:
		sum(W3G.Navegaciones) as Num_tests,
		sum(W3G.[Fallos de acceso]) as Failed,
		sum(W3G.[Navegaciones fallidas]) as Dropped,
		sum(cast(W3G.[Session Time] as float)*W3G.[Count_SessionTime]) as Session_time_Num,
		sum(0) as Throughput_Den,
		sum(W3G.[Count_SessionTime]) as Session_time_Den,
		sum(0) as Throughput_Num,
		max(0) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(0) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(0) as Throughput_with_Error_Den,
		sum(0) as Throughput_with_Error_Num,
		sum(cast(W3G.[IP Service Setup Time] as float)*W3G.[Count_IPServiceSetupTime]) as WEB_IP_ACCESS_TIME_NUM,
		sum(W3G.[Count_IPServiceSetupTime]) as WEB_IP_ACCESS_TIME_DEN,
		sum(cast(W3G.[Transfer Time] as float)*W3G.[Count_TransferTime]) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(W3G.[Count_TransferTime]) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(0) as Radio_2G_use_Num,
		sum(0) as Radio_3G_use_Num,
		sum(0) as Radio_4G_use_Num,
		sum(0) as Radio_use_Den,
		sum(0) as Radio_2G_use_Den,
		sum(0) as Radio_3G_use_Den,
		sum(0) as Radio_4G_use_Den,

		sum(0) as Radio_U2100_use_Num,
		sum(0) as Radio_U900_use_Num,
		sum(0) as Radio_LTE2100_use_Num,
		sum(0) as Radio_LTE2600_use_Num,
		sum(0) as Radio_LTE1800_use_Num,
		sum(0) as Radio_LTE800_use_Num,
		sum(0) as Radio_Band_Use_Den,
		sum(0) as Radio_U2100_use_Den,
		sum(0) as Radio_U900_use_Den,
		sum(0) as Radio_LTE2100_use_Den,
		sum(0) as Radio_LTE2600_use_Den,
		sum(0) as Radio_LTE1800_use_Den,
		sum(0) as Radio_LTE800_use_Den,

		sum(0) as [3G_DualCarrier_use_Num],
		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],
		sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],
		sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],
		sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],
		sum(0) as [3G_16QAM_use_Num],
		sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],
		sum(0) as [3G_16QAM_use_Den],
		sum(0) as [3G_64QAM_use_Den],

		sum(0) as [3G_%_SF22_Num],
		sum(0) as [3G_%_SF22andSF42_Num],
		sum(0) as [3G_%_SF4_Num],
		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],
		sum(0) as [3G_%_SF22andSF42_Den],
		sum(0) as [3G_%_SF4_Den],
		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],
		sum(0) as [3G_%_TTI2ms_Den],	
	
		sum(0) as [RSCP_Lin_Num],
		sum(0) as [EcI0_Lin_Num],	
		sum(0) as [RSCP_Lin_Den],	
		sum(0) as [EcI0_Lin_Den],
		
		-- Performance:
		sum(0) as [3G_CQI],
		sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,
		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,
		sum(0) as CQI_U2100_Den,

		sum(0) as [HSPA_PCT_Num],
		sum(0) as [HSPA+_PCT_Num],
		sum(0) as [HSPA+_DC_PCT_Num],
		sum(0) as [HSPA_PCT_Den],
		sum(0) as [HSPA+_PCT_Den],
		sum(0) as [HSPA+_DC_PCT_Den],

		sum(0) as [UL_Inter_Lin_Num],
		sum(0) as [UL_Inter_Lin_Den],
	
		-- Performance LTE:
		sum(0) as CQI_4G_Num,
		sum(0) as CQI_L800_Num,
		sum(0) as CQI_L1800_Num,
		sum(0) as CQI_L2100_Num,
		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,
		sum(0) as CQI_L800_Den,
		sum(0) as CQI_L1800_Den,
		sum(0) as CQI_L2100_Den,
		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,
		sum(0) as LTE_10Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_SC_Use_Num,
		sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,
		sum(0) as LTE_20Mhz_CA_Use_Num,
		sum(0) as LTE_25Mhz_CA_Use_Num,
		sum(0) as LTE_30Mhz_CA_Use_Num,
		sum(0) as LTE_35Mhz_CA_Use_Num,
		sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,
		sum(0) as LTE_10Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_SC_Use_Den,
		sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,
		sum(0) as LTE_20Mhz_CA_Use_Den,
		sum(0) as LTE_25Mhz_CA_Use_Den,
		sum(0) as LTE_30Mhz_CA_Use_Den,
		sum(0) as LTE_35Mhz_CA_Use_Den,
		sum(0) as LTE_40Mhz_CA_Use_Den,

		sum(0) as LTE_BW_use_den,	
		sum(0) as [4G_RBs_use_Num],
		sum(0) as [4G_RBs_use_Den],

		sum(0) as [4G_TM1_use_Num],
		sum(0) as [4G_TM2_use_Num],
		sum(0) as [4G_TM3_use_Num],
		sum(0) as [4G_TM4_use_Num],
		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],
		sum(0) as [4G_TM7_use_Num],
		sum(0) as [4G_TM8_use_Num],
		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],
		sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],
	
		-- Technology LTE:
		sum(0) as [4G_%CA_Num],
		sum(0) as [4G_%CA_Den],
		sum(0) as [4G_BPSK_Use_Num],
		sum(0) as [4G_QPSK_Use_Num],
		sum(0) as [4G_16QAM_Use_Num],
		sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],
		sum(0) as [4G_QPSK_Use_Den],
		sum(0) as [4G_16QAM_Use_Den],
		sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],
		sum(0) as [RSRP_Lin_Num],
		sum(0) as [RSRQ_Lin_Num],
		sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],
		sum(0) as [RSRQ_Lin_Den],
		sum(0) as [SINR_Lin_Den],		

		--New KPIs:
		sum(0) as [MIMO_num],
		sum(0) as [RI1_num],
		sum(0) as [RI2_num],
		sum(0) as [MIMO_den],
		sum(0) as [RI1_den],
		sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,
		sum(0) as RBs_Allocated_Num,
		max(0) as RBs_Allocated_Max,	
	
		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(0) as [1_N],	sum(0) as [2_N],	sum(0) as [3_N],	sum(0) as [4_N],	sum(0) as [5_N],	sum(0) as [6_N],	sum(0) as [7_N],	sum(0) as [8_N],	sum(0) as [9_N],	sum(0) as [10_N],
		sum(0) as [11_N],	sum(0) as [12_N],	sum(0) as [13_N],	sum(0) as [14_N],	sum(0) as [15_N],	sum(0) as [16_N],	sum(0) as [17_N],	sum(0) as [18_N],	sum(0) as [19_N],	sum(0) as [20_N],
		sum(0) as [21_N],	sum(0) as [22_N],	sum(0) as [23_N],	sum(0) as [24_N],	sum(0) as [25_N],	sum(0) as [26_N],	sum(0) as [27_N],	sum(0) as [28_N],	sum(0) as [29_N],	sum(0) as [30_N],
		sum(0) as [31_N],	sum(0) as [32_N],	sum(0) as [33_N],	sum(0) as [34_N],	sum(0) as [35_N],	sum(0) as [36_N],	sum(0) as [37_N],	sum(0) as [38_N],	sum(0) as [39_N],	sum(0) as [40_N],
		sum(0) as [41_N],	sum(0) as [42_N],	sum(0) as [43_N],	sum(0) as [44_N],	sum(0) as [45_N],	sum(0) as [46_N],	sum(0) as [47_N],	sum(0) as [48_N],	sum(0) as [49_N],	sum(0) as [50_N],
		sum(0) as [51_N],	sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(0) as [1]	,sum(0) as [2]	,sum(0) as [3]	,sum(0) as [4]	,sum(0) as [5]	,sum(0) as [6]	,sum(0) as [7]	,sum(0) as [8]	,sum(0) as [9]	,sum(0) as [10]
		,sum(0) as [11]	,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]	,sum(0) as [30]
		,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]
		,sum(0) as [41],

		-- Parametros de configuracion:
		t.ASideDevice as ASideDevice, t.BSideDevice as BSideDevice, t.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from [aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_Web] t
			left outer join [aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_Web_3G] W3G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(W3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=W3G.mnc and t.Date_Reporting=W3G.Date_Reporting and t.entidad=W3G.entidad and t.Aggr_Type=W3G.Aggr_Type and t.Report_Type=W3G.Report_Type and t.meas_round=W3G.meas_round)
		, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		t.ASideDevice, t.BSideDevice, t.SWVersion--, t.Region_VF, t.Region_OSP,

	-----------
	union all	-- WEB HTTPS 3GOnly_4G
	select  
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'3GOnly_4G' as meas_Tech, 'WEB HTTPS' as Test_type, 'Downlink' as Direction, t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
		
		-- General:
		sum(W3G.[Navegaciones HTTPS]) as Num_tests,
		sum(W3G.[Fallos de acceso HTTPS]) as Failed,
		sum(W3G.[Navegaciones fallidas HTTPS]) as Dropped,
		sum(cast(W3G.[Session Time HTTPS] as float)*W3G.[Count_SessionTime HTTPS]) as Session_time_Num,
		sum(0) as Throughput_Den,
		sum(W3G.[Count_SessionTime HTTPS]) as Session_time_Den,
		sum(0) as Throughput_Num,
		max(0) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(0) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(0) as Throughput_with_Error_Den,
		sum(0) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(cast(W3G.[IP Service Setup Time HTTPS] as float)*W3G.[Count_IPServiceSetupTime HTTPS]) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(W3G.[Count_IPServiceSetupTime HTTPS]) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(cast(W3G.[Transfer Time HTTPS] as float)*W3G.[Count_TransferTime HTTPS]) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(W3G.[Count_TransferTime HTTPS]) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(0) as Radio_2G_use_Num,
		sum(0) as Radio_3G_use_Num,
		sum(0) as Radio_4G_use_Num,
		sum(0) as Radio_use_Den,
		sum(0) as Radio_2G_use_Den,
		sum(0) as Radio_3G_use_Den,
		sum(0) as Radio_4G_use_Den,

		sum(0) as Radio_U2100_use_Num,
		sum(0) as Radio_U900_use_Num,
		sum(0) as Radio_LTE2100_use_Num,
		sum(0) as Radio_LTE2600_use_Num,
		sum(0) as Radio_LTE1800_use_Num,
		sum(0) as Radio_LTE800_use_Num,
		sum(0) as Radio_Band_Use_Den,
		sum(0) as Radio_U2100_use_Den,
		sum(0) as Radio_U900_use_Den,
		sum(0) as Radio_LTE2100_use_Den,
		sum(0) as Radio_LTE2600_use_Den,
		sum(0) as Radio_LTE1800_use_Den,
		sum(0) as Radio_LTE800_use_Den,

		sum(0) as [3G_DualCarrier_use_Num],
		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],
		sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],
		sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],
		sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],
		sum(0) as [3G_16QAM_use_Num],
		sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],
		sum(0) as [3G_16QAM_use_Den],
		sum(0) as [3G_64QAM_use_Den],

		sum(0) as [3G_%_SF22_Num],
		sum(0) as [3G_%_SF22andSF42_Num],
		sum(0) as [3G_%_SF4_Num],
		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],
		sum(0) as [3G_%_SF22andSF42_Den],
		sum(0) as [3G_%_SF4_Den],
		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],
		sum(0) as [3G_%_TTI2ms_Den],	
	
		sum(0) as [RSCP_Lin_Num],
		sum(0) as [EcI0_Lin_Num],	
		sum(0) as [RSCP_Lin_Den],	
		sum(0) as [EcI0_Lin_Den],
		
		-- Performance:
		sum(0) as [3G_CQI],
		sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,
		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,
		sum(0) as CQI_U2100_Den,

		sum(0) as [HSPA_PCT_Num],
		sum(0) as [HSPA+_PCT_Num],
		sum(0) as [HSPA+_DC_PCT_Num],
		sum(0) as [HSPA_PCT_Den],
		sum(0) as [HSPA+_PCT_Den],
		sum(0) as [HSPA+_DC_PCT_Den],

		sum(0) as [UL_Inter_Lin_Num],
		sum(0) as [UL_Inter_Lin_Den],
	
		-- Performance LTE:
		sum(0) as CQI_4G_Num,
		sum(0) as CQI_L800_Num,
		sum(0) as CQI_L1800_Num,
		sum(0) as CQI_L2100_Num,
		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,
		sum(0) as CQI_L800_Den,
		sum(0) as CQI_L1800_Den,
		sum(0) as CQI_L2100_Den,
		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,
		sum(0) as LTE_10Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_SC_Use_Num,
		sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,
		sum(0) as LTE_20Mhz_CA_Use_Num,
		sum(0) as LTE_25Mhz_CA_Use_Num,
		sum(0) as LTE_30Mhz_CA_Use_Num,
		sum(0) as LTE_35Mhz_CA_Use_Num,
		sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,
		sum(0) as LTE_10Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_SC_Use_Den,
		sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,
		sum(0) as LTE_20Mhz_CA_Use_Den,
		sum(0) as LTE_25Mhz_CA_Use_Den,
		sum(0) as LTE_30Mhz_CA_Use_Den,
		sum(0) as LTE_35Mhz_CA_Use_Den,
		sum(0) as LTE_40Mhz_CA_Use_Den,

		sum(0) as LTE_BW_use_den,	
		sum(0) as [4G_RBs_use_Num],
		sum(0) as [4G_RBs_use_Den],

		sum(0) as [4G_TM1_use_Num],
		sum(0) as [4G_TM2_use_Num],
		sum(0) as [4G_TM3_use_Num],
		sum(0) as [4G_TM4_use_Num],
		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],
		sum(0) as [4G_TM7_use_Num],
		sum(0) as [4G_TM8_use_Num],
		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],
		sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],
		sum(0) as [4G_%CA_Den],
		sum(0) as [4G_BPSK_Use_Num],
		sum(0) as [4G_QPSK_Use_Num],
		sum(0) as [4G_16QAM_Use_Num],
		sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],
		sum(0) as [4G_QPSK_Use_Den],
		sum(0) as [4G_16QAM_Use_Den],
		sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],
		sum(0) as [RSRP_Lin_Num],
		sum(0) as [RSRQ_Lin_Num],
		sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],
		sum(0) as [RSRQ_Lin_Den],
		sum(0) as [SINR_Lin_Den],		

		--New KPIs:
		sum(0) as [MIMO_num],
		sum(0) as [RI1_num],
		sum(0) as [RI2_num],
		sum(0) as [MIMO_den],
		sum(0) as [RI1_den],
		sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,
		sum(0) as RBs_Allocated_Num,
		max(0) as RBs_Allocated_Max,	
	
		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(0) as [1_N],	sum(0) as [2_N],	sum(0) as [3_N],	sum(0) as [4_N],	sum(0) as [5_N],	sum(0) as [6_N],	sum(0) as [7_N],	sum(0) as [8_N],	sum(0) as [9_N],	sum(0) as [10_N],
		sum(0) as [11_N],	sum(0) as [12_N],	sum(0) as [13_N],	sum(0) as [14_N],	sum(0) as [15_N],	sum(0) as [16_N],	sum(0) as [17_N],	sum(0) as [18_N],	sum(0) as [19_N],	sum(0) as [20_N],
		sum(0) as [21_N],	sum(0) as [22_N],	sum(0) as [23_N],	sum(0) as [24_N],	sum(0) as [25_N],	sum(0) as [26_N],	sum(0) as [27_N],	sum(0) as [28_N],	sum(0) as [29_N],	sum(0) as [30_N],
		sum(0) as [31_N],	sum(0) as [32_N],	sum(0) as [33_N],	sum(0) as [34_N],	sum(0) as [35_N],	sum(0) as [36_N],	sum(0) as [37_N],	sum(0) as [38_N],	sum(0) as [39_N],	sum(0) as [40_N],
		sum(0) as [41_N],	sum(0) as [42_N],	sum(0) as [43_N],	sum(0) as [44_N],	sum(0) as [45_N],	sum(0) as [46_N],	sum(0) as [47_N],	sum(0) as [48_N],	sum(0) as [49_N],	sum(0) as [50_N],
		sum(0) as [51_N],	sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(0) as [1]	,sum(0) as [2]	,sum(0) as [3]	,sum(0) as [4]	,sum(0) as [5]	,sum(0) as [6]	,sum(0) as [7]	,sum(0) as [8]	,sum(0) as [9]	,sum(0) as [10]
		,sum(0) as [11]	,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]	,sum(0) as [30]
		,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]
		,sum(0) as [41],

		-- Parametros de configuracion:
		t.ASideDevice as ASideDevice, t.BSideDevice as BSideDevice, t.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Web] t
			left outer join  [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Web_3G] W3G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(W3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=W3G.mnc and t.Date_Reporting=W3G.Date_Reporting and t.entidad=W3G.entidad and t.Aggr_Type=W3G.Aggr_Type and t.Report_Type=W3G.Report_Type and t.meas_round=W3G.meas_round)
		, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		t.ASideDevice, t.BSideDevice, t.SWVersion--, t.Region_VF, t.Region_OSP
	
	-----------
	union all	-- WEB HTTPS Road 3GOnly
	select  
		p.codigo_ine, 'Roads' vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'Road 3GOnly' as meas_Tech, 'WEB HTTPS' as Test_type, 'Downlink' as Direction, t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
		
		-- General:
		sum(W3G.[Navegaciones HTTPS]) as Num_tests,
		sum(W3G.[Fallos de acceso HTTPS]) as Failed,
		sum(W3G.[Navegaciones fallidas HTTPS]) as Dropped,
		sum(cast(W3G.[Session Time HTTPS] as float)*W3G.[Count_SessionTime HTTPS]) as Session_time_Num,
		sum(0) as Throughput_Den,
		sum(W3G.[Count_SessionTime HTTPS]) as Session_time_Den,
		sum(0) as Throughput_Num,
		max(0) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(0) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(0) as Throughput_with_Error_Den,
		sum(0) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(cast(W3G.[IP Service Setup Time HTTPS] as float)*W3G.[Count_IPServiceSetupTime HTTPS]) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(W3G.[Count_IPServiceSetupTime HTTPS]) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(cast(W3G.[Transfer Time HTTPS] as float)*W3G.[Count_TransferTime HTTPS]) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(W3G.[Count_TransferTime HTTPS]) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(0) as Radio_2G_use_Num,
		sum(0) as Radio_3G_use_Num,
		sum(0) as Radio_4G_use_Num,
		sum(0) as Radio_use_Den,
		sum(0) as Radio_2G_use_Den,
		sum(0) as Radio_3G_use_Den,
		sum(0) as Radio_4G_use_Den,

		sum(0) as Radio_U2100_use_Num,
		sum(0) as Radio_U900_use_Num,
		sum(0) as Radio_LTE2100_use_Num,
		sum(0) as Radio_LTE2600_use_Num,
		sum(0) as Radio_LTE1800_use_Num,
		sum(0) as Radio_LTE800_use_Num,
		sum(0) as Radio_Band_Use_Den,
		sum(0) as Radio_U2100_use_Den,
		sum(0) as Radio_U900_use_Den,
		sum(0) as Radio_LTE2100_use_Den,
		sum(0) as Radio_LTE2600_use_Den,
		sum(0) as Radio_LTE1800_use_Den,
		sum(0) as Radio_LTE800_use_Den,

		sum(0) as [3G_DualCarrier_use_Num],
		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],
		sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],
		sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],
		sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],
		sum(0) as [3G_16QAM_use_Num],
		sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],
		sum(0) as [3G_16QAM_use_Den],
		sum(0) as [3G_64QAM_use_Den],

		sum(0) as [3G_%_SF22_Num],
		sum(0) as [3G_%_SF22andSF42_Num],
		sum(0) as [3G_%_SF4_Num],
		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],
		sum(0) as [3G_%_SF22andSF42_Den],
		sum(0) as [3G_%_SF4_Den],
		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],
		sum(0) as [3G_%_TTI2ms_Den],	
	
		sum(0) as [RSCP_Lin_Num],
		sum(0) as [EcI0_Lin_Num],	
		sum(0) as [RSCP_Lin_Den],	
		sum(0) as [EcI0_Lin_Den],
		
		-- Performance:
		sum(0) as [3G_CQI],
		sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,
		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,
		sum(0) as CQI_U2100_Den,

		sum(0) as [HSPA_PCT_Num],
		sum(0) as [HSPA+_PCT_Num],
		sum(0) as [HSPA+_DC_PCT_Num],
		sum(0) as [HSPA_PCT_Den],
		sum(0) as [HSPA+_PCT_Den],
		sum(0) as [HSPA+_DC_PCT_Den],

		sum(0) as [UL_Inter_Lin_Num],
		sum(0) as [UL_Inter_Lin_Den],
	
		-- Performance LTE:
		sum(0) as CQI_4G_Num,
		sum(0) as CQI_L800_Num,
		sum(0) as CQI_L1800_Num,
		sum(0) as CQI_L2100_Num,
		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,
		sum(0) as CQI_L800_Den,
		sum(0) as CQI_L1800_Den,
		sum(0) as CQI_L2100_Den,
		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,
		sum(0) as LTE_10Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_SC_Use_Num,
		sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,
		sum(0) as LTE_20Mhz_CA_Use_Num,
		sum(0) as LTE_25Mhz_CA_Use_Num,
		sum(0) as LTE_30Mhz_CA_Use_Num,
		sum(0) as LTE_35Mhz_CA_Use_Num,
		sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,
		sum(0) as LTE_10Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_SC_Use_Den,
		sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,
		sum(0) as LTE_20Mhz_CA_Use_Den,
		sum(0) as LTE_25Mhz_CA_Use_Den,
		sum(0) as LTE_30Mhz_CA_Use_Den,
		sum(0) as LTE_35Mhz_CA_Use_Den,
		sum(0) as LTE_40Mhz_CA_Use_Den,

		sum(0) as LTE_BW_use_den,	
		sum(0) as [4G_RBs_use_Num],
		sum(0) as [4G_RBs_use_Den],

		sum(0) as [4G_TM1_use_Num],
		sum(0) as [4G_TM2_use_Num],
		sum(0) as [4G_TM3_use_Num],
		sum(0) as [4G_TM4_use_Num],
		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],
		sum(0) as [4G_TM7_use_Num],
		sum(0) as [4G_TM8_use_Num],
		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],
		sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],
		sum(0) as [4G_%CA_Den],
		sum(0) as [4G_BPSK_Use_Num],
		sum(0) as [4G_QPSK_Use_Num],
		sum(0) as [4G_16QAM_Use_Num],
		sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],
		sum(0) as [4G_QPSK_Use_Den],
		sum(0) as [4G_16QAM_Use_Den],
		sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],
		sum(0) as [RSRP_Lin_Num],
		sum(0) as [RSRQ_Lin_Num],
		sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],
		sum(0) as [RSRQ_Lin_Den],
		sum(0) as [SINR_Lin_Den],		

		--New KPIs:
		sum(0) as [MIMO_num],
		sum(0) as [RI1_num],
		sum(0) as [RI2_num],
		sum(0) as [MIMO_den],
		sum(0) as [RI1_den],
		sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,
		sum(0) as RBs_Allocated_Num,
		max(0) as RBs_Allocated_Max,	
	
		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(0) as [1_N],	sum(0) as [2_N],	sum(0) as [3_N],	sum(0) as [4_N],	sum(0) as [5_N],	sum(0) as [6_N],	sum(0) as [7_N],	sum(0) as [8_N],	sum(0) as [9_N],	sum(0) as [10_N],
		sum(0) as [11_N],	sum(0) as [12_N],	sum(0) as [13_N],	sum(0) as [14_N],	sum(0) as [15_N],	sum(0) as [16_N],	sum(0) as [17_N],	sum(0) as [18_N],	sum(0) as [19_N],	sum(0) as [20_N],
		sum(0) as [21_N],	sum(0) as [22_N],	sum(0) as [23_N],	sum(0) as [24_N],	sum(0) as [25_N],	sum(0) as [26_N],	sum(0) as [27_N],	sum(0) as [28_N],	sum(0) as [29_N],	sum(0) as [30_N],
		sum(0) as [31_N],	sum(0) as [32_N],	sum(0) as [33_N],	sum(0) as [34_N],	sum(0) as [35_N],	sum(0) as [36_N],	sum(0) as [37_N],	sum(0) as [38_N],	sum(0) as [39_N],	sum(0) as [40_N],
		sum(0) as [41_N],	sum(0) as [42_N],	sum(0) as [43_N],	sum(0) as [44_N],	sum(0) as [45_N],	sum(0) as [46_N],	sum(0) as [47_N],	sum(0) as [48_N],	sum(0) as [49_N],	sum(0) as [50_N],
		sum(0) as [51_N],	sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(0) as [1]	,sum(0) as [2]	,sum(0) as [3]	,sum(0) as [4]	,sum(0) as [5]	,sum(0) as [6]	,sum(0) as [7]	,sum(0) as [8]	,sum(0) as [9]	,sum(0) as [10]
		,sum(0) as [11]	,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]	,sum(0) as [30]
		,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]
		,sum(0) as [41],

		-- Parametros de configuracion:
		t.ASideDevice as ASideDevice, t.BSideDevice as BSideDevice, t.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from [aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_Web] t
			left outer join [aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_Web_3G] W3G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(W3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=W3G.mnc and t.Date_Reporting=W3G.Date_Reporting and t.entidad=W3G.entidad and t.Aggr_Type=W3G.Aggr_Type and t.Report_Type=W3G.Report_Type and t.meas_round=W3G.meas_round)
		, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type, 
		t.ASideDevice, t.BSideDevice, t.SWVersion --,t.Region_VF, t.Region_OSP,

	-----------
	union all	-- WEB Public 3GOnly_4G
	select  
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'3GOnly_4G' as meas_Tech, 'WEB Public' as Test_type, 'Downlink' as Direction,  t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
		
		-- General:
		sum(W3G.[Navegaciones Public]) as Num_tests,
		sum(W3G.[Fallos de acceso public]) as Failed,
		sum(W3G.[Navegaciones fallidas public]) as Dropped,
		sum(cast(W3G.[Session Time public] as float)*W3G.[Count_SessionTime public]) as Session_time_Num,
		sum(0) as Throughput_Den,
		sum(W3G.[Count_SessionTime public]) as Session_time_Den,
		sum(0) as Throughput_Num,
		max(0) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(0) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(0) as Throughput_with_Error_Den,
		sum(0) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(cast(W3G.[IP Service Setup Time Public] as float)*W3G.[Count_IPServiceSetupTime Public]) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(W3G.[Count_IPServiceSetupTime Public]) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(cast(W3G.[Transfer Time Public] as float)*W3G.[Count_TransferTime Public]) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(W3G.[Count_TransferTime Public]) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(0) as Radio_2G_use_Num,
		sum(0) as Radio_3G_use_Num,
		sum(0) as Radio_4G_use_Num,
		sum(0) as Radio_use_Den,
		sum(0) as Radio_2G_use_Den,
		sum(0) as Radio_3G_use_Den,
		sum(0) as Radio_4G_use_Den,

		sum(0) as Radio_U2100_use_Num,
		sum(0) as Radio_U900_use_Num,
		sum(0) as Radio_LTE2100_use_Num,
		sum(0) as Radio_LTE2600_use_Num,
		sum(0) as Radio_LTE1800_use_Num,
		sum(0) as Radio_LTE800_use_Num,
		sum(0) as Radio_Band_Use_Den,
		sum(0) as Radio_U2100_use_Den,
		sum(0) as Radio_U900_use_Den,
		sum(0) as Radio_LTE2100_use_Den,
		sum(0) as Radio_LTE2600_use_Den,
		sum(0) as Radio_LTE1800_use_Den,
		sum(0) as Radio_LTE800_use_Den,

		sum(0) as [3G_DualCarrier_use_Num],
		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],
		sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],
		sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],
		sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],
		sum(0) as [3G_16QAM_use_Num],
		sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],
		sum(0) as [3G_16QAM_use_Den],
		sum(0) as [3G_64QAM_use_Den],

		sum(0) as [3G_%_SF22_Num],
		sum(0) as [3G_%_SF22andSF42_Num],
		sum(0) as [3G_%_SF4_Num],
		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],
		sum(0) as [3G_%_SF22andSF42_Den],
		sum(0) as [3G_%_SF4_Den],
		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],
		sum(0) as [3G_%_TTI2ms_Den],	
	
		sum(0) as [RSCP_Lin_Num],
		sum(0) as [EcI0_Lin_Num],	
		sum(0) as [RSCP_Lin_Den],	
		sum(0) as [EcI0_Lin_Den],
		
		-- Performance:
		sum(0) as [3G_CQI],
		sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,
		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,
		sum(0) as CQI_U2100_Den,

		sum(0) as [HSPA_PCT_Num],
		sum(0) as [HSPA+_PCT_Num],
		sum(0) as [HSPA+_DC_PCT_Num],
		sum(0) as [HSPA_PCT_Den],
		sum(0) as [HSPA+_PCT_Den],
		sum(0) as [HSPA+_DC_PCT_Den],

		sum(0) as [UL_Inter_Lin_Num],
		sum(0) as [UL_Inter_Lin_Den],
	
		-- Performance LTE:
		sum(0) as CQI_4G_Num,
		sum(0) as CQI_L800_Num,
		sum(0) as CQI_L1800_Num,
		sum(0) as CQI_L2100_Num,
		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,
		sum(0) as CQI_L800_Den,
		sum(0) as CQI_L1800_Den,
		sum(0) as CQI_L2100_Den,
		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,
		sum(0) as LTE_10Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_SC_Use_Num,
		sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,
		sum(0) as LTE_20Mhz_CA_Use_Num,
		sum(0) as LTE_25Mhz_CA_Use_Num,
		sum(0) as LTE_30Mhz_CA_Use_Num,
		sum(0) as LTE_35Mhz_CA_Use_Num,
		sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,
		sum(0) as LTE_10Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_SC_Use_Den,
		sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,
		sum(0) as LTE_20Mhz_CA_Use_Den,
		sum(0) as LTE_25Mhz_CA_Use_Den,
		sum(0) as LTE_30Mhz_CA_Use_Den,
		sum(0) as LTE_35Mhz_CA_Use_Den,
		sum(0) as LTE_40Mhz_CA_Use_Den,

		sum(0) as LTE_BW_use_den,	
		sum(0) as [4G_RBs_use_Num],
		sum(0) as [4G_RBs_use_Den],

		sum(0) as [4G_TM1_use_Num],
		sum(0) as [4G_TM2_use_Num],
		sum(0) as [4G_TM3_use_Num],
		sum(0) as [4G_TM4_use_Num],
		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],
		sum(0) as [4G_TM7_use_Num],
		sum(0) as [4G_TM8_use_Num],
		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],
		sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],
		sum(0) as [4G_%CA_Den],
		sum(0) as [4G_BPSK_Use_Num],
		sum(0) as [4G_QPSK_Use_Num],
		sum(0) as [4G_16QAM_Use_Num],
		sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],
		sum(0) as [4G_QPSK_Use_Den],
		sum(0) as [4G_16QAM_Use_Den],
		sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],
		sum(0) as [RSRP_Lin_Num],
		sum(0) as [RSRQ_Lin_Num],
		sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],
		sum(0) as [RSRQ_Lin_Den],
		sum(0) as [SINR_Lin_Den],		

		--New KPIs:
		sum(0) as [MIMO_num],
		sum(0) as [RI1_num],
		sum(0) as [RI2_num],
		sum(0) as [MIMO_den],
		sum(0) as [RI1_den],
		sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,
		sum(0) as RBs_Allocated_Num,
		max(0) as RBs_Allocated_Max,	
	
		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(0) as [1_N],	sum(0) as [2_N],	sum(0) as [3_N],	sum(0) as [4_N],	sum(0) as [5_N],	sum(0) as [6_N],	sum(0) as [7_N],	sum(0) as [8_N],	sum(0) as [9_N],	sum(0) as [10_N],
		sum(0) as [11_N],	sum(0) as [12_N],	sum(0) as [13_N],	sum(0) as [14_N],	sum(0) as [15_N],	sum(0) as [16_N],	sum(0) as [17_N],	sum(0) as [18_N],	sum(0) as [19_N],	sum(0) as [20_N],
		sum(0) as [21_N],	sum(0) as [22_N],	sum(0) as [23_N],	sum(0) as [24_N],	sum(0) as [25_N],	sum(0) as [26_N],	sum(0) as [27_N],	sum(0) as [28_N],	sum(0) as [29_N],	sum(0) as [30_N],
		sum(0) as [31_N],	sum(0) as [32_N],	sum(0) as [33_N],	sum(0) as [34_N],	sum(0) as [35_N],	sum(0) as [36_N],	sum(0) as [37_N],	sum(0) as [38_N],	sum(0) as [39_N],	sum(0) as [40_N],
		sum(0) as [41_N],	sum(0) as [42_N],	sum(0) as [43_N],	sum(0) as [44_N],	sum(0) as [45_N],	sum(0) as [46_N],	sum(0) as [47_N],	sum(0) as [48_N],	sum(0) as [49_N],	sum(0) as [50_N],
		sum(0) as [51_N],	sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(0) as [1]	,sum(0) as [2]	,sum(0) as [3]	,sum(0) as [4]	,sum(0) as [5]	,sum(0) as [6]	,sum(0) as [7]	,sum(0) as [8]	,sum(0) as [9]	,sum(0) as [10]
		,sum(0) as [11]	,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]	,sum(0) as [30]
		,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]
		,sum(0) as [41],

		-- Parametros de configuracion:
		t.ASideDevice as ASideDevice, t.BSideDevice as BSideDevice, t.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Web] t
			left outer join [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Web_3G] W3G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(W3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=W3G.mnc and t.Date_Reporting=W3G.Date_Reporting and t.entidad=W3G.entidad and t.Aggr_Type=W3G.Aggr_Type and t.Report_Type=W3G.Report_Type and t.meas_round=W3G.meas_round)
		, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		t.ASideDevice, t.BSideDevice, t.SWVersion--, t.Region_VF, t.Region_OSP

	-----------
	union all	-- WEB Public Road 3GOnly
	select  
		p.codigo_ine, 'Roads' vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'Road 3GOnly' as meas_Tech, 'WEB Public' as Test_type, 'Downlink' as Direction, t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
		
		-- General:
		sum(W3G.[Navegaciones Public]) as Num_tests,
		sum(W3G.[Fallos de acceso public]) as Failed,
		sum(W3G.[Navegaciones fallidas public]) as Dropped,
		sum(cast(W3G.[Session Time public] as float)*W3G.[Count_SessionTime public]) as Session_time_Num,
		sum(0) as Throughput_Den,
		sum(W3G.[Count_SessionTime public]) as Session_time_Den,
		sum(0) as Throughput_Num,
		max(0) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(0) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(0) as Throughput_with_Error_Den,
		sum(0) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(cast(W3G.[IP Service Setup Time Public] as float)*W3G.[Count_IPServiceSetupTime Public]) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(W3G.[Count_IPServiceSetupTime Public]) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(cast(W3G.[Transfer Time Public] as float)*W3G.[Count_TransferTime Public]) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(W3G.[Count_TransferTime Public]) as WEB_TRANSFER_TIME_PUBLIC_DEN,

		-- Technology:
		sum(0) as Radio_2G_use_Num,
		sum(0) as Radio_3G_use_Num,
		sum(0) as Radio_4G_use_Num,
		sum(0) as Radio_use_Den,
		sum(0) as Radio_2G_use_Den,
		sum(0) as Radio_3G_use_Den,
		sum(0) as Radio_4G_use_Den,

		sum(0) as Radio_U2100_use_Num,
		sum(0) as Radio_U900_use_Num,
		sum(0) as Radio_LTE2100_use_Num,
		sum(0) as Radio_LTE2600_use_Num,
		sum(0) as Radio_LTE1800_use_Num,
		sum(0) as Radio_LTE800_use_Num,
		sum(0) as Radio_Band_Use_Den,
		sum(0) as Radio_U2100_use_Den,
		sum(0) as Radio_U900_use_Den,
		sum(0) as Radio_LTE2100_use_Den,
		sum(0) as Radio_LTE2600_use_Den,
		sum(0) as Radio_LTE1800_use_Den,
		sum(0) as Radio_LTE800_use_Den,

		sum(0) as [3G_DualCarrier_use_Num],
		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],
		sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],
		sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],
		sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],
		sum(0) as [3G_16QAM_use_Num],
		sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],
		sum(0) as [3G_16QAM_use_Den],
		sum(0) as [3G_64QAM_use_Den],

		sum(0) as [3G_%_SF22_Num],
		sum(0) as [3G_%_SF22andSF42_Num],
		sum(0) as [3G_%_SF4_Num],
		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],
		sum(0) as [3G_%_SF22andSF42_Den],
		sum(0) as [3G_%_SF4_Den],
		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],
		sum(0) as [3G_%_TTI2ms_Den],	
	
		sum(0) as [RSCP_Lin_Num],
		sum(0) as [EcI0_Lin_Num],	
		sum(0) as [RSCP_Lin_Den],	
		sum(0) as [EcI0_Lin_Den],
		
		-- Performance:
		sum(0) as [3G_CQI],
		sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,
		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,
		sum(0) as CQI_U2100_Den,

		sum(0) as [HSPA_PCT_Num],
		sum(0) as [HSPA+_PCT_Num],
		sum(0) as [HSPA+_DC_PCT_Num],
		sum(0) as [HSPA_PCT_Den],
		sum(0) as [HSPA+_PCT_Den],
		sum(0) as [HSPA+_DC_PCT_Den],

		sum(0) as [UL_Inter_Lin_Num],
		sum(0) as [UL_Inter_Lin_Den],
	
		-- Performance LTE:
		sum(0) as CQI_4G_Num,
		sum(0) as CQI_L800_Num,
		sum(0) as CQI_L1800_Num,
		sum(0) as CQI_L2100_Num,
		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,
		sum(0) as CQI_L800_Den,
		sum(0) as CQI_L1800_Den,
		sum(0) as CQI_L2100_Den,
		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,
		sum(0) as LTE_10Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_SC_Use_Num,
		sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,
		sum(0) as LTE_20Mhz_CA_Use_Num,
		sum(0) as LTE_25Mhz_CA_Use_Num,
		sum(0) as LTE_30Mhz_CA_Use_Num,
		sum(0) as LTE_35Mhz_CA_Use_Num,
		sum(0) as LTE_40Mhz_CA_Use_Num,
		sum(0) as LTE_5Mhz_SC_Use_Den,
		sum(0) as LTE_10Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_SC_Use_Den,
		sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,
		sum(0) as LTE_20Mhz_CA_Use_Den,
		sum(0) as LTE_25Mhz_CA_Use_Den,
		sum(0) as LTE_30Mhz_CA_Use_Den,
		sum(0) as LTE_35Mhz_CA_Use_Den,
		sum(0) as LTE_40Mhz_CA_Use_Den,
		
		sum(0) as LTE_BW_use_den,	
		sum(0) as [4G_RBs_use_Num],
		sum(0) as [4G_RBs_use_Den],

		sum(0) as [4G_TM1_use_Num],
		sum(0) as [4G_TM2_use_Num],
		sum(0) as [4G_TM3_use_Num],
		sum(0) as [4G_TM4_use_Num],
		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],
		sum(0) as [4G_TM7_use_Num],
		sum(0) as [4G_TM8_use_Num],
		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],
		sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],
		sum(0) as [4G_%CA_Den],
		sum(0) as [4G_BPSK_Use_Num],
		sum(0) as [4G_QPSK_Use_Num],
		sum(0) as [4G_16QAM_Use_Num],
		sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],
		sum(0) as [4G_QPSK_Use_Den],
		sum(0) as [4G_16QAM_Use_Den],
		sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],
		sum(0) as [RSRP_Lin_Num],
		sum(0) as [RSRQ_Lin_Num],
		sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],
		sum(0) as [RSRQ_Lin_Den],
		sum(0) as [SINR_Lin_Den],		

		--New KPIs:
		sum(0) as [MIMO_num],
		sum(0) as [RI1_num],
		sum(0) as [RI2_num],
		sum(0) as [MIMO_den],
		sum(0) as [RI1_den],
		sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,
		sum(0) as RBs_Allocated_Num,
		max(0) as RBs_Allocated_Max,	
	
		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(0) as [1_N],	sum(0) as [2_N],	sum(0) as [3_N],	sum(0) as [4_N],	sum(0) as [5_N],	sum(0) as [6_N],	sum(0) as [7_N],	sum(0) as [8_N],	sum(0) as [9_N],	sum(0) as [10_N],
		sum(0) as [11_N],	sum(0) as [12_N],	sum(0) as [13_N],	sum(0) as [14_N],	sum(0) as [15_N],	sum(0) as [16_N],	sum(0) as [17_N],	sum(0) as [18_N],	sum(0) as [19_N],	sum(0) as [20_N],
		sum(0) as [21_N],	sum(0) as [22_N],	sum(0) as [23_N],	sum(0) as [24_N],	sum(0) as [25_N],	sum(0) as [26_N],	sum(0) as [27_N],	sum(0) as [28_N],	sum(0) as [29_N],	sum(0) as [30_N],
		sum(0) as [31_N],	sum(0) as [32_N],	sum(0) as [33_N],	sum(0) as [34_N],	sum(0) as [35_N],	sum(0) as [36_N],	sum(0) as [37_N],	sum(0) as [38_N],	sum(0) as [39_N],	sum(0) as [40_N],
		sum(0) as [41_N],	sum(0) as [42_N],	sum(0) as [43_N],	sum(0) as [44_N],	sum(0) as [45_N],	sum(0) as [46_N],	sum(0) as [47_N],	sum(0) as [48_N],	sum(0) as [49_N],	sum(0) as [50_N],
		sum(0) as [51_N],	sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(0) as [1]	,sum(0) as [2]	,sum(0) as [3]	,sum(0) as [4]	,sum(0) as [5]	,sum(0) as [6]	,sum(0) as [7]	,sum(0) as [8]	,sum(0) as [9]	,sum(0) as [10]
		,sum(0) as [11]	,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]	,sum(0) as [30]
		,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]
		,sum(0) as [41],

		-- Parametros de configuracion:
		t.ASideDevice as ASideDevice, t.BSideDevice as BSideDevice, t.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from [aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_Web] t
			left outer join [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Web_3G] W3G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(W3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=W3G.mnc and t.Date_Reporting=W3G.Date_Reporting and t.entidad=W3G.entidad and t.Aggr_Type=W3G.Aggr_Type and t.Report_Type=W3G.Report_Type and t.meas_round=W3G.meas_round)
		, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		t.ASideDevice, t.BSideDevice, t.SWVersion--, t.Region_VF, t.Region_OSP
	
	-------------
	-- 3GOnly_4G YTB SD y ROAD 	
	insert into _RI_Data_e	
	select  
		p.codigo_ine, case when  t.entidad like 'AVE-%' or  t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'3GOnly_4G' as meas_Tech, 'Youtube SD' as Test_type, 'Downlink' as Direction,  t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
		
		-- General:
		sum( YTB3G.Reproducciones) as Num_tests,
		sum( YTB3G.Fails) as Failed,
		sum( YTB3G.reproducciones- YTB3G.fails- YTB3G.[Successful video download]) as Dropped,
		sum(0) as Session_time_Num,
		sum(0) as Throughput_Den,
		sum(0) as Session_time_Den,
		sum(0) as Throughput_Num,
		max(0) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(0) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(0) as Throughput_with_Error_Den,
		sum(0) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,
	
		-- Technology:
		sum(0) as Radio_2G_use_Num,
		sum(0) as Radio_3G_use_Num,
		sum(0) as Radio_4G_use_Num,
		sum(0) as Radio_use_Den,
		sum(0) as Radio_2G_use_Den,
		sum(0) as Radio_3G_use_Den,
		sum(0) as Radio_4G_use_Den,

		sum(0) as Radio_U2100_use_Num,
		sum(0) as Radio_U900_use_Num,
		sum(0) as Radio_LTE2100_use_Num,
		sum(0) as Radio_LTE2600_use_Num,
		sum(0) as Radio_LTE1800_use_Num,
		sum(0) as Radio_LTE800_use_Num,
		sum(0) as Radio_Band_Use_Den,
		sum(0) as Radio_U2100_use_Den,
		sum(0) as Radio_U900_use_Den,
		sum(0) as Radio_LTE2100_use_Den,
		sum(0) as Radio_LTE2600_use_Den,
		sum(0) as Radio_LTE1800_use_Den,
		sum(0) as Radio_LTE800_use_Den,

		sum(0) as [3G_DualCarrier_use_Num],
		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],
		sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],
		sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],
		sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],
		sum(0) as [3G_16QAM_use_Num],
		sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],
		sum(0) as [3G_16QAM_use_Den],
		sum(0) as [3G_64QAM_use_Den],

		sum(0) as [3G_%_SF22_Num],
		sum(0) as [3G_%_SF22andSF42_Num],
		sum(0) as [3G_%_SF4_Num],
		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],
		sum(0) as [3G_%_SF22andSF42_Den],
		sum(0) as [3G_%_SF4_Den],
		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],
		sum(0) as [3G_%_TTI2ms_Den],	
	
		sum(0) as [RSCP_Lin_Num],
		sum(0) as [EcI0_Lin_Num],	
		sum(0) as [RSCP_Lin_Den],	
		sum(0) as [EcI0_Lin_Den],
		
		-- Performance:
		sum(0) as [3G_CQI],
		sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,
		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,
		sum(0) as CQI_U2100_Den,

		sum(0) as [HSPA_PCT_Num],
		sum(0) as [HSPA+_PCT_Num],
		sum(0) as [HSPA+_DC_PCT_Num],
		sum(0) as [HSPA_PCT_Den],
		sum(0) as [HSPA+_PCT_Den],
		sum(0) as [HSPA+_DC_PCT_Den],

		sum(0) as [UL_Inter_Lin_Num],
		sum(0) as [UL_Inter_Lin_Den],
	
		-- Performance LTE:
		sum(0) as CQI_4G_Num,
		sum(0) as CQI_L800_Num,
		sum(0) as CQI_L1800_Num,
		sum(0) as CQI_L2100_Num,
		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,
		sum(0) as CQI_L800_Den,
		sum(0) as CQI_L1800_Den,
		sum(0) as CQI_L2100_Den,
		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,
		sum(0) as LTE_10Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_SC_Use_Num,
		sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,
		sum(0) as LTE_20Mhz_CA_Use_Num,
		sum(0) as LTE_25Mhz_CA_Use_Num,
		sum(0) as LTE_30Mhz_CA_Use_Num,
		sum(0) as LTE_35Mhz_CA_Use_Num,
		sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,
		sum(0) as LTE_10Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_SC_Use_Den,
		sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,
		sum(0) as LTE_20Mhz_CA_Use_Den,
		sum(0) as LTE_25Mhz_CA_Use_Den,
		sum(0) as LTE_30Mhz_CA_Use_Den,
		sum(0) as LTE_35Mhz_CA_Use_Den,
		sum(0) as LTE_40Mhz_CA_Use_Den,

		sum(0) as LTE_BW_use_den,	
		sum(0) as [4G_RBs_use_Num],
		sum(0) as [4G_RBs_use_Den],

		sum(0) as [4G_TM1_use_Num],
		sum(0) as [4G_TM2_use_Num],
		sum(0) as [4G_TM3_use_Num],
		sum(0) as [4G_TM4_use_Num],
		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],
		sum(0) as [4G_TM7_use_Num],
		sum(0) as [4G_TM8_use_Num],
		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],
		sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],
		sum(0) as [4G_%CA_Den],
		sum(0) as [4G_BPSK_Use_Num],
		sum(0) as [4G_QPSK_Use_Num],
		sum(0) as [4G_16QAM_Use_Num],
		sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],
		sum(0) as [4G_QPSK_Use_Den],
		sum(0) as [4G_16QAM_Use_Den],
		sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],
		sum(0) as [RSRP_Lin_Num],
		sum(0) as [RSRQ_Lin_Num],
		sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],
		sum(0) as [RSRQ_Lin_Den],
		sum(0) as [SINR_Lin_Den],		

		--New KPIs:
		sum(0) as [MIMO_num],
		sum(0) as [RI1_num],
		sum(0) as [RI2_num],
		sum(0) as [MIMO_den],
		sum(0) as [RI1_den],
		sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,
		sum(0) as RBs_Allocated_Num,
		max(0) as RBs_Allocated_Max,	
	
		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(0) as [1_N],	sum(0) as [2_N],	sum(0) as [3_N],	sum(0) as [4_N],	sum(0) as [5_N],	sum(0) as [6_N],	sum(0) as [7_N],	sum(0) as [8_N],	sum(0) as [9_N],	sum(0) as [10_N],
		sum(0) as [11_N],	sum(0) as [12_N],	sum(0) as [13_N],	sum(0) as [14_N],	sum(0) as [15_N],	sum(0) as [16_N],	sum(0) as [17_N],	sum(0) as [18_N],	sum(0) as [19_N],	sum(0) as [20_N],
		sum(0) as [21_N],	sum(0) as [22_N],	sum(0) as [23_N],	sum(0) as [24_N],	sum(0) as [25_N],	sum(0) as [26_N],	sum(0) as [27_N],	sum(0) as [28_N],	sum(0) as [29_N],	sum(0) as [30_N],
		sum(0) as [31_N],	sum(0) as [32_N],	sum(0) as [33_N],	sum(0) as [34_N],	sum(0) as [35_N],	sum(0) as [36_N],	sum(0) as [37_N],	sum(0) as [38_N],	sum(0) as [39_N],	sum(0) as [40_N],
		sum(0) as [41_N],	sum(0) as [42_N],	sum(0) as [43_N],	sum(0) as [44_N],	sum(0) as [45_N],	sum(0) as [46_N],	sum(0) as [47_N],	sum(0) as [48_N],	sum(0) as [49_N],	sum(0) as [50_N],
		sum(0) as [51_N],	sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(0) as [1]	,sum(0) as [2]	,sum(0) as [3]	,sum(0) as [4]	,sum(0) as [5]	,sum(0) as [6]	,sum(0) as [7]	,sum(0) as [8]	,sum(0) as [9]	,sum(0) as [10]
		,sum(0) as [11]	,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]	,sum(0) as [30]
		,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]
		,sum(0) as [41],

		-- Parametros de configuracion:
		t.ASideDevice as ASideDevice, t.BSideDevice as BSideDevice, t.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL


	from [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Youtube] t
			left outer join [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Youtube_3G] YTB3G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(YTB3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=YTB3G.mnc and t.Date_Reporting=YTB3G.Date_Reporting and t.entidad=YTB3G.entidad and t.Aggr_Type=YTB3G.Aggr_Type and t.Report_Type=YTB3G.Report_Type and t.meas_round=YTB3G.meas_round)
		, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when  t.entidad like 'AVE-%' or  t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		t.ASideDevice, t.BSideDevice, t.SWVersion--, t.Region_VF, t.Region_OSP

	-----------
	union all	-- YTB SD Road 3GOnly
	select  
		p.codigo_ine, 'Roads' vf_environment,  t.mnc,  t.meas_round,  t.Date_Reporting as meas_date,  t.Week_Reporting as meas_week, 
		'Road 3GOnly' as meas_Tech, 'Youtube SD' as Test_type, 'Downlink' as Direction,  t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
		
		-- General:
		sum(YTB3G.Reproducciones) as Num_tests,
		sum(YTB3G.Fails) as Failed,
		sum(YTB3G.[reproducciones] - YTB3G.[fails] - YTB3G.[Successful video download]) as Dropped,
		sum(0) as Session_time_Num,
		sum(0) as Throughput_Den,
		sum(0) as Session_time_Den,
		sum(0) as Throughput_Num,
		max(0) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(0) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(0) as Throughput_with_Error_Den,
		sum(0) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,
	
		-- Technology:
		sum(0) as Radio_2G_use_Num,
		sum(0) as Radio_3G_use_Num,
		sum(0) as Radio_4G_use_Num,
		sum(0) as Radio_use_Den,
		sum(0) as Radio_2G_use_Den,
		sum(0) as Radio_3G_use_Den,
		sum(0) as Radio_4G_use_Den,

		sum(0) as Radio_U2100_use_Num,
		sum(0) as Radio_U900_use_Num,
		sum(0) as Radio_LTE2100_use_Num,
		sum(0) as Radio_LTE2600_use_Num,
		sum(0) as Radio_LTE1800_use_Num,
		sum(0) as Radio_LTE800_use_Num,
		sum(0) as Radio_Band_Use_Den,
		sum(0) as Radio_U2100_use_Den,
		sum(0) as Radio_U900_use_Den,
		sum(0) as Radio_LTE2100_use_Den,
		sum(0) as Radio_LTE2600_use_Den,
		sum(0) as Radio_LTE1800_use_Den,
		sum(0) as Radio_LTE800_use_Den,

		sum(0) as [3G_DualCarrier_use_Num],
		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],
		sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],
		sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],
		sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],
		sum(0) as [3G_16QAM_use_Num],
		sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],
		sum(0) as [3G_16QAM_use_Den],
		sum(0) as [3G_64QAM_use_Den],

		sum(0) as [3G_%_SF22_Num],
		sum(0) as [3G_%_SF22andSF42_Num],
		sum(0) as [3G_%_SF4_Num],
		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],
		sum(0) as [3G_%_SF22andSF42_Den],
		sum(0) as [3G_%_SF4_Den],
		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],
		sum(0) as [3G_%_TTI2ms_Den],	
	
		sum(0) as [RSCP_Lin_Num],
		sum(0) as [EcI0_Lin_Num],	
		sum(0) as [RSCP_Lin_Den],	
		sum(0) as [EcI0_Lin_Den],
		
		-- Performance:
		sum(0) as [3G_CQI],
		sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,
		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,
		sum(0) as CQI_U2100_Den,

		sum(0) as [HSPA_PCT_Num],
		sum(0) as [HSPA+_PCT_Num],
		sum(0) as [HSPA+_DC_PCT_Num],
		sum(0) as [HSPA_PCT_Den],
		sum(0) as [HSPA+_PCT_Den],
		sum(0) as [HSPA+_DC_PCT_Den],

		sum(0) as [UL_Inter_Lin_Num],
		sum(0) as [UL_Inter_Lin_Den],
	
		-- Performance LTE:
		sum(0) as CQI_4G_Num,
		sum(0) as CQI_L800_Num,
		sum(0) as CQI_L1800_Num,
		sum(0) as CQI_L2100_Num,
		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,
		sum(0) as CQI_L800_Den,
		sum(0) as CQI_L1800_Den,
		sum(0) as CQI_L2100_Den,
		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,
		sum(0) as LTE_10Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_SC_Use_Num,
		sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,
		sum(0) as LTE_20Mhz_CA_Use_Num,
		sum(0) as LTE_25Mhz_CA_Use_Num,
		sum(0) as LTE_30Mhz_CA_Use_Num,
		sum(0) as LTE_35Mhz_CA_Use_Num,
		sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,
		sum(0) as LTE_10Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_SC_Use_Den,
		sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,
		sum(0) as LTE_20Mhz_CA_Use_Den,
		sum(0) as LTE_25Mhz_CA_Use_Den,
		sum(0) as LTE_30Mhz_CA_Use_Den,
		sum(0) as LTE_35Mhz_CA_Use_Den,
		sum(0) as LTE_40Mhz_CA_Use_Den,

		sum(0) as LTE_BW_use_den,	
		sum(0) as [4G_RBs_use_Num],
		sum(0) as [4G_RBs_use_Den],

		sum(0) as [4G_TM1_use_Num],
		sum(0) as [4G_TM2_use_Num],
		sum(0) as [4G_TM3_use_Num],
		sum(0) as [4G_TM4_use_Num],
		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],
		sum(0) as [4G_TM7_use_Num],
		sum(0) as [4G_TM8_use_Num],
		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],
		sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],
		sum(0) as [4G_%CA_Den],
		sum(0) as [4G_BPSK_Use_Num],
		sum(0) as [4G_QPSK_Use_Num],
		sum(0) as [4G_16QAM_Use_Num],
		sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],
		sum(0) as [4G_QPSK_Use_Den],
		sum(0) as [4G_16QAM_Use_Den],
		sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],
		sum(0) as [RSRP_Lin_Num],
		sum(0) as [RSRQ_Lin_Num],
		sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],
		sum(0) as [RSRQ_Lin_Den],
		sum(0) as [SINR_Lin_Den],		

		--New KPIs:
		sum(0) as [MIMO_num],
		sum(0) as [RI1_num],
		sum(0) as [RI2_num],
		sum(0) as [MIMO_den],
		sum(0) as [RI1_den],
		sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,
		sum(0) as RBs_Allocated_Num,
		max(0) as RBs_Allocated_Max,	
	
		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(0) as [1_N],	sum(0) as [2_N],	sum(0) as [3_N],	sum(0) as [4_N],	sum(0) as [5_N],	sum(0) as [6_N],	sum(0) as [7_N],	sum(0) as [8_N],	sum(0) as [9_N],	sum(0) as [10_N],
		sum(0) as [11_N],	sum(0) as [12_N],	sum(0) as [13_N],	sum(0) as [14_N],	sum(0) as [15_N],	sum(0) as [16_N],	sum(0) as [17_N],	sum(0) as [18_N],	sum(0) as [19_N],	sum(0) as [20_N],
		sum(0) as [21_N],	sum(0) as [22_N],	sum(0) as [23_N],	sum(0) as [24_N],	sum(0) as [25_N],	sum(0) as [26_N],	sum(0) as [27_N],	sum(0) as [28_N],	sum(0) as [29_N],	sum(0) as [30_N],
		sum(0) as [31_N],	sum(0) as [32_N],	sum(0) as [33_N],	sum(0) as [34_N],	sum(0) as [35_N],	sum(0) as [36_N],	sum(0) as [37_N],	sum(0) as [38_N],	sum(0) as [39_N],	sum(0) as [40_N],
		sum(0) as [41_N],	sum(0) as [42_N],	sum(0) as [43_N],	sum(0) as [44_N],	sum(0) as [45_N],	sum(0) as [46_N],	sum(0) as [47_N],	sum(0) as [48_N],	sum(0) as [49_N],	sum(0) as [50_N],
		sum(0) as [51_N],	sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(0) as [1]	,sum(0) as [2]	,sum(0) as [3]	,sum(0) as [4]	,sum(0) as [5]	,sum(0) as [6]	,sum(0) as [7]	,sum(0) as [8]	,sum(0) as [9]	,sum(0) as [10]
		,sum(0) as [11]	,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]	,sum(0) as [30]
		,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]
		,sum(0) as [41],

		-- Parametros de configuracion:
		t.ASideDevice as ASideDevice, t.BSideDevice as BSideDevice, t.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from [aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_Youtube] t
			left outer join [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Youtube_3G] YTB3G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(YTB3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=YTB3G.mnc and t.Date_Reporting=YTB3G.Date_Reporting and t.entidad=YTB3G.entidad and t.Aggr_Type=YTB3G.Aggr_Type and t.Report_Type=YTB3G.Report_Type and t.meas_round=YTB3G.meas_round)
		, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		t.ASideDevice, t.BSideDevice, t.SWVersion--, t.Region_VF, t.Region_OSP

	-------------
	-- 3GOnly_4G YTB HD	
	insert into _RI_Data_e	
	select  
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date,t.Week_Reporting as meas_week, 
		'3GOnly_4G' as meas_Tech, 'Youtube HD' as Test_type, 'Downlink' as Direction, t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
		
		-- General:
		sum(YTB3G.Reproducciones) as Num_tests,
		sum(YTB3G.Fails) as Failed,
		sum(YTB3G.[reproducciones] - YTB3G.[fails] - YTB3G.[Successful video download]) as Dropped,
		sum(0) as Session_time_Num,
		sum(0) as Throughput_Den,
		sum(0) as Session_time_Den,
		sum(0) as Throughput_Num,
		max(0) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(0) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(0) as Throughput_with_Error_Den,
		sum(0) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,
	
		-- Technology:
		sum(0) as Radio_2G_use_Num,
		sum(0) as Radio_3G_use_Num,
		sum(0) as Radio_4G_use_Num,
		sum(0) as Radio_use_Den,
		sum(0) as Radio_2G_use_Den,
		sum(0) as Radio_3G_use_Den,
		sum(0) as Radio_4G_use_Den,

		sum(0) as Radio_U2100_use_Num,
		sum(0) as Radio_U900_use_Num,
		sum(0) as Radio_LTE2100_use_Num,
		sum(0) as Radio_LTE2600_use_Num,
		sum(0) as Radio_LTE1800_use_Num,
		sum(0) as Radio_LTE800_use_Num,
		sum(0) as Radio_Band_Use_Den,
		sum(0) as Radio_U2100_use_Den,
		sum(0) as Radio_U900_use_Den,
		sum(0) as Radio_LTE2100_use_Den,
		sum(0) as Radio_LTE2600_use_Den,
		sum(0) as Radio_LTE1800_use_Den,
		sum(0) as Radio_LTE800_use_Den,

		sum(0) as [3G_DualCarrier_use_Num],
		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],
		sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],
		sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],
		sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],
		sum(0) as [3G_16QAM_use_Num],
		sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],
		sum(0) as [3G_16QAM_use_Den],
		sum(0) as [3G_64QAM_use_Den],

		sum(0) as [3G_%_SF22_Num],
		sum(0) as [3G_%_SF22andSF42_Num],
		sum(0) as [3G_%_SF4_Num],
		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],
		sum(0) as [3G_%_SF22andSF42_Den],
		sum(0) as [3G_%_SF4_Den],
		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],
		sum(0) as [3G_%_TTI2ms_Den],	
	
		sum(0) as [RSCP_Lin_Num],
		sum(0) as [EcI0_Lin_Num],	
		sum(0) as [RSCP_Lin_Den],	
		sum(0) as [EcI0_Lin_Den],
		
		-- Performance:
		sum(0) as [3G_CQI],
		sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,
		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,
		sum(0) as CQI_U2100_Den,

		sum(0) as [HSPA_PCT_Num],
		sum(0) as [HSPA+_PCT_Num],
		sum(0) as [HSPA+_DC_PCT_Num],
		sum(0) as [HSPA_PCT_Den],
		sum(0) as [HSPA+_PCT_Den],
		sum(0) as [HSPA+_DC_PCT_Den],

		sum(0) as [UL_Inter_Lin_Num],
		sum(0) as [UL_Inter_Lin_Den],
	
		-- Performance LTE:
		sum(0) as CQI_4G_Num,
		sum(0) as CQI_L800_Num,
		sum(0) as CQI_L1800_Num,
		sum(0) as CQI_L2100_Num,
		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,
		sum(0) as CQI_L800_Den,
		sum(0) as CQI_L1800_Den,
		sum(0) as CQI_L2100_Den,
		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,
		sum(0) as LTE_10Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_SC_Use_Num,
		sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,
		sum(0) as LTE_20Mhz_CA_Use_Num,
		sum(0) as LTE_25Mhz_CA_Use_Num,
		sum(0) as LTE_30Mhz_CA_Use_Num,
		sum(0) as LTE_35Mhz_CA_Use_Num,
		sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,
		sum(0) as LTE_10Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_SC_Use_Den,
		sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,
		sum(0) as LTE_20Mhz_CA_Use_Den,
		sum(0) as LTE_25Mhz_CA_Use_Den,
		sum(0) as LTE_30Mhz_CA_Use_Den,
		sum(0) as LTE_35Mhz_CA_Use_Den,
		sum(0) as LTE_40Mhz_CA_Use_Den,

		sum(0) as LTE_BW_use_den,
		sum(0) as [4G_RBs_use_Num],
		sum(0) as [4G_RBs_use_Den],

		sum(0) as [4G_TM1_use_Num],
		sum(0) as [4G_TM2_use_Num],
		sum(0) as [4G_TM3_use_Num],
		sum(0) as [4G_TM4_use_Num],
		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],
		sum(0) as [4G_TM7_use_Num],
		sum(0) as [4G_TM8_use_Num],
		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],
		sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],
		sum(0) as [4G_%CA_Den],
		sum(0) as [4G_BPSK_Use_Num],
		sum(0) as [4G_QPSK_Use_Num],
		sum(0) as [4G_16QAM_Use_Num],
		sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],
		sum(0) as [4G_QPSK_Use_Den],
		sum(0) as [4G_16QAM_Use_Den],
		sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],
		sum(0) as [RSRP_Lin_Num],
		sum(0) as [RSRQ_Lin_Num],
		sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],
		sum(0) as [RSRQ_Lin_Den],
		sum(0) as [SINR_Lin_Den],		

		--New KPIs:
		sum(0) as [MIMO_num],
		sum(0) as [RI1_num],
		sum(0) as [RI2_num],
		sum(0) as [MIMO_den],
		sum(0) as [RI1_den],
		sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,
		sum(0) as RBs_Allocated_Num,
		max(0) as RBs_Allocated_Max,	
	
		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(0) as [1_N],	sum(0) as [2_N],	sum(0) as [3_N],	sum(0) as [4_N],	sum(0) as [5_N],	sum(0) as [6_N],	sum(0) as [7_N],	sum(0) as [8_N],	sum(0) as [9_N],	sum(0) as [10_N],
		sum(0) as [11_N],	sum(0) as [12_N],	sum(0) as [13_N],	sum(0) as [14_N],	sum(0) as [15_N],	sum(0) as [16_N],	sum(0) as [17_N],	sum(0) as [18_N],	sum(0) as [19_N],	sum(0) as [20_N],
		sum(0) as [21_N],	sum(0) as [22_N],	sum(0) as [23_N],	sum(0) as [24_N],	sum(0) as [25_N],	sum(0) as [26_N],	sum(0) as [27_N],	sum(0) as [28_N],	sum(0) as [29_N],	sum(0) as [30_N],
		sum(0) as [31_N],	sum(0) as [32_N],	sum(0) as [33_N],	sum(0) as [34_N],	sum(0) as [35_N],	sum(0) as [36_N],	sum(0) as [37_N],	sum(0) as [38_N],	sum(0) as [39_N],	sum(0) as [40_N],
		sum(0) as [41_N],	sum(0) as [42_N],	sum(0) as [43_N],	sum(0) as [44_N],	sum(0) as [45_N],	sum(0) as [46_N],	sum(0) as [47_N],	sum(0) as [48_N],	sum(0) as [49_N],	sum(0) as [50_N],
		sum(0) as [51_N],	sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(0) as [1]	,sum(0) as [2]	,sum(0) as [3]	,sum(0) as [4]	,sum(0) as [5]	,sum(0) as [6]	,sum(0) as [7]	,sum(0) as [8]	,sum(0) as [9]	,sum(0) as [10]
		,sum(0) as [11]	,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]	,sum(0) as [30]
		,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]
		,sum(0) as [41],

		-- Parametros de configuracion:
		t.ASideDevice as ASideDevice, t.BSideDevice as BSideDevice, t.SWVersion as SWVersion, 
		max(t.Youtube_Version) as YTB_Version, max(t.url) as YTB_URL		

	from [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Youtube_HD] t
			left outer join [AGGRData4G].dbo.[lcc_aggr_sp_MDD_Data_Youtube_HD_3G] YTB3G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(YTB3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=YTB3G.mnc and t.Date_Reporting=YTB3G.Date_Reporting and t.entidad=YTB3G.entidad and t.Aggr_Type=YTB3G.Aggr_Type and t.Report_Type=YTB3G.Report_Type and t.meas_round=YTB3G.meas_round)		
		, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end, t.mnc, t.meas_round, t.Date_Reporting, t.Week_Reporting, t.entidad, t.Report_Type, t.Aggr_Type,
		t.ASideDevice, t.BSideDevice, t.SWVersion--, t.Youtube_Version, t.url	--, t.Region_VF, t.Region_OSP

	-----------
	union all	-- YTB HD Road 3GOnly
	select  
		p.codigo_ine, 'Roads' vf_environment, t.mnc, t.meas_round, t.Date_Reporting as meas_date, t.Week_Reporting as meas_week, 
		'Road 3GOnly' as meas_Tech, 'Youtube HD' as Test_type, 'Downlink' as Direction, t.entidad as vf_entity, t.Report_Type, t.Aggr_Type,
		
		-- General:
		sum(YTB3G.Reproducciones) as Num_tests,
		sum(YTB3G.Fails) as Failed,
		sum(YTB3G.[reproducciones] - YTB3G.[fails] - YTB3G.[Successful video download]) as Dropped,
		sum(0) as Session_time_Num,
		sum(0) as Throughput_Den,
		sum(0) as Session_time_Den,
		sum(0) as Throughput_Num,
		max(0) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(0) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(0) as Throughput_with_Error_Den,
		sum(0) as Throughput_with_Error_Num,
		sum(0) as WEB_IP_ACCESS_TIME_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_DEN,
		sum(0) as WEB_HTTP_TRANSFER_TIME_NUM,
		sum(0) as WEB_HTTP_TRANSFER_TIME_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_HTTPS_DEN,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_NUM,
		sum(0) as WEB_TRANSFER_TIME_HTTPS_DEN,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_NUM,
		sum(0) as WEB_IP_ACCESS_TIME_PUBLIC_DEN,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_NUM,
		sum(0) as WEB_TRANSFER_TIME_PUBLIC_DEN,
	
		-- Technology:
		sum(0) as Radio_2G_use_Num,
		sum(0) as Radio_3G_use_Num,
		sum(0) as Radio_4G_use_Num,
		sum(0) as Radio_use_Den,
		sum(0) as Radio_2G_use_Den,
		sum(0) as Radio_3G_use_Den,
		sum(0) as Radio_4G_use_Den,

		sum(0) as Radio_U2100_use_Num,
		sum(0) as Radio_U900_use_Num,
		sum(0) as Radio_LTE2100_use_Num,
		sum(0) as Radio_LTE2600_use_Num,
		sum(0) as Radio_LTE1800_use_Num,
		sum(0) as Radio_LTE800_use_Num,
		sum(0) as Radio_Band_Use_Den,
		sum(0) as Radio_U2100_use_Den,
		sum(0) as Radio_U900_use_Den,
		sum(0) as Radio_LTE2100_use_Den,
		sum(0) as Radio_LTE2600_use_Den,
		sum(0) as Radio_LTE1800_use_Den,
		sum(0) as Radio_LTE800_use_Den,

		sum(0) as [3G_DualCarrier_use_Num],
		sum(0) as [3G_DualCarrier_use_Den],
		sum(0) as [3G_DC_2100_use_Num],
		sum(0) as [3G_DC_2100_use_Den],
		sum(0) as [3G_DC_900_use_Num],
		sum(0) as [3G_DC_900_use_Den],

		sum(0) as [3G_NumCodes_use_Num],
		sum(0) as [3G_NumCodes_use_Den],
		sum(0) as [3G_QPSK_use_Num],
		sum(0) as [3G_16QAM_use_Num],
		sum(0) as [3G_64QAM_use_Num],
		sum(0) as [3G_QPSK_use_Den],
		sum(0) as [3G_16QAM_use_Den],
		sum(0) as [3G_64QAM_use_Den],

		sum(0) as [3G_%_SF22_Num],
		sum(0) as [3G_%_SF22andSF42_Num],
		sum(0) as [3G_%_SF4_Num],
		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],
		sum(0) as [3G_%_SF22andSF42_Den],
		sum(0) as [3G_%_SF4_Den],
		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],
		sum(0) as [3G_%_TTI2ms_Den],	
	
		sum(0) as [RSCP_Lin_Num],
		sum(0) as [EcI0_Lin_Num],	
		sum(0) as [RSCP_Lin_Den],	
		sum(0) as [EcI0_Lin_Den],
		
		-- Performance:
		sum(0) as [3G_CQI],
		sum(0) as [3G_DataStats_Den],
		Sum(0) as CQI_U900_Num,
		sum(0) as CQI_U900_Den,
		Sum(0) as CQI_U2100_Num,
		sum(0) as CQI_U2100_Den,

		sum(0) as [HSPA_PCT_Num],
		sum(0) as [HSPA+_PCT_Num],
		sum(0) as [HSPA+_DC_PCT_Num],
		sum(0) as [HSPA_PCT_Den],
		sum(0) as [HSPA+_PCT_Den],
		sum(0) as [HSPA+_DC_PCT_Den],

		sum(0) as [UL_Inter_Lin_Num],
		sum(0) as [UL_Inter_Lin_Den],
	
		-- Performance LTE:
		sum(0) as CQI_4G_Num,
		sum(0) as CQI_L800_Num,
		sum(0) as CQI_L1800_Num,
		sum(0) as CQI_L2100_Num,
		sum(0) as CQI_L2600_Num,
		sum(0) as CQI_4G_Den,
		sum(0) as CQI_L800_Den,
		sum(0) as CQI_L1800_Den,
		sum(0) as CQI_L2100_Den,
		sum(0) as CQI_L2600_Den,

		sum(0) as LTE_5Mhz_SC_Use_Num,
		sum(0) as LTE_10Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_SC_Use_Num,
		sum(0) as LTE_20Mhz_SC_Use_Num,
		sum(0) as LTE_15Mhz_CA_Use_Num,
		sum(0) as LTE_20Mhz_CA_Use_Num,
		sum(0) as LTE_25Mhz_CA_Use_Num,
		sum(0) as LTE_30Mhz_CA_Use_Num,
		sum(0) as LTE_35Mhz_CA_Use_Num,
		sum(0) as LTE_40Mhz_CA_Use_Num,	
		sum(0) as LTE_5Mhz_SC_Use_Den,
		sum(0) as LTE_10Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_SC_Use_Den,
		sum(0) as LTE_20Mhz_SC_Use_Den,
		sum(0) as LTE_15Mhz_CA_Use_Den,
		sum(0) as LTE_20Mhz_CA_Use_Den,
		sum(0) as LTE_25Mhz_CA_Use_Den,
		sum(0) as LTE_30Mhz_CA_Use_Den,
		sum(0) as LTE_35Mhz_CA_Use_Den,
		sum(0) as LTE_40Mhz_CA_Use_Den,

		sum(0) as LTE_BW_use_den,	
		sum(0) as [4G_RBs_use_Num],
		sum(0) as [4G_RBs_use_Den],

		sum(0) as [4G_TM1_use_Num],
		sum(0) as [4G_TM2_use_Num],
		sum(0) as [4G_TM3_use_Num],
		sum(0) as [4G_TM4_use_Num],
		sum(0) as [4G_TM5_use_Num],
		sum(0) as [4G_TM6_use_Num],
		sum(0) as [4G_TM7_use_Num],
		sum(0) as [4G_TM8_use_Num],
		sum(0) as [4G_TM9_use_Num],
		sum(0) as [4G_TMInvalid_use_Num],
		sum(0) as [4G_TMUnknown_use_Num],
		sum(0) as [4G_TM_Den],

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],
		sum(0) as [4G_%CA_Den],
		sum(0) as [4G_BPSK_Use_Num],
		sum(0) as [4G_QPSK_Use_Num],
		sum(0) as [4G_16QAM_Use_Num],
		sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],
		sum(0) as [4G_QPSK_Use_Den],
		sum(0) as [4G_16QAM_Use_Den],
		sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],
		sum(0) as [RSRP_Lin_Num],
		sum(0) as [RSRQ_Lin_Num],
		sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],
		sum(0) as [RSRQ_Lin_Den],
		sum(0) as [SINR_Lin_Den],		

		--New KPIs:
		sum(0) as [MIMO_num],
		sum(0) as [RI1_num],
		sum(0) as [RI2_num],
		sum(0) as [MIMO_den],
		sum(0) as [RI1_den],
		sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,
		sum(0) as RBs_Allocated_Num,
		max(0) as RBs_Allocated_Max,	
	
		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(0) as [1_N],	sum(0) as [2_N],	sum(0) as [3_N],	sum(0) as [4_N],	sum(0) as [5_N],	sum(0) as [6_N],	sum(0) as [7_N],	sum(0) as [8_N],	sum(0) as [9_N],	sum(0) as [10_N],
		sum(0) as [11_N],	sum(0) as [12_N],	sum(0) as [13_N],	sum(0) as [14_N],	sum(0) as [15_N],	sum(0) as [16_N],	sum(0) as [17_N],	sum(0) as [18_N],	sum(0) as [19_N],	sum(0) as [20_N],
		sum(0) as [21_N],	sum(0) as [22_N],	sum(0) as [23_N],	sum(0) as [24_N],	sum(0) as [25_N],	sum(0) as [26_N],	sum(0) as [27_N],	sum(0) as [28_N],	sum(0) as [29_N],	sum(0) as [30_N],
		sum(0) as [31_N],	sum(0) as [32_N],	sum(0) as [33_N],	sum(0) as [34_N],	sum(0) as [35_N],	sum(0) as [36_N],	sum(0) as [37_N],	sum(0) as [38_N],	sum(0) as [39_N],	sum(0) as [40_N],
		sum(0) as [41_N],	sum(0) as [42_N],	sum(0) as [43_N],	sum(0) as [44_N],	sum(0) as [45_N],	sum(0) as [46_N],	sum(0) as [47_N],	sum(0) as [48_N],	sum(0) as [49_N],	sum(0) as [50_N],
		sum(0) as [51_N],	sum(0) as [52_N],	sum(0) as [53_N],	sum(0) as [54_N],	sum(0) as [55_N],	sum(0) as [56_N],	sum(0) as [57_N],	sum(0) as [58_N],	sum(0) as [59_N],	sum(0) as [60_N],
		sum(0) as [61_N],	sum(0) as [62_N],	sum(0) as [63_N],	sum(0) as [64_N],	sum(0) as [65_N],	sum(0) as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(0) as [1]	,sum(0) as [2]	,sum(0) as [3]	,sum(0) as [4]	,sum(0) as [5]	,sum(0) as [6]	,sum(0) as [7]	,sum(0) as [8]	,sum(0) as [9]	,sum(0) as [10]
		,sum(0) as [11]	,sum(0) as [12]	,sum(0) as [13]	,sum(0) as [14]	,sum(0) as [15]	,sum(0) as [16]	,sum(0) as [17]	,sum(0) as [18]	,sum(0) as [19]	,sum(0) as [20]
		,sum(0) as [21]	,sum(0) as [22]	,sum(0) as [23]	,sum(0) as [24]	,sum(0) as [25]	,sum(0) as [26]	,sum(0) as [27]	,sum(0) as [28]	,sum(0) as [29]	,sum(0) as [30]
		,sum(0) as [31]	,sum(0) as [32]	,sum(0) as [33]	,sum(0) as [34]	,sum(0) as [35]	,sum(0) as [36]	,sum(0) as [37]	,sum(0) as [38]	,sum(0) as [39]	,sum(0) as [40]
		,sum(0) as [41],

		-- Parametros de configuracion:
		t.ASideDevice as ASideDevice, t.BSideDevice as BSideDevice, t.SWVersion as SWVersion, 
		max(t.Youtube_Version) as YTB_Version, max(t.url) as YTB_URL		


	from [aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_Youtube_HD] t
			left outer join [aggrData4G_ROAD].dbo.[lcc_aggr_sp_MDD_Data_Youtube_HD_3G] YTB3G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(YTB3G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=YTB3G.mnc and t.Date_Reporting=YTB3G.Date_Reporting and t.entidad=YTB3G.entidad and t.Aggr_Type=YTB3G.Aggr_Type and t.Report_Type=YTB3G.Report_Type and t.meas_round=YTB3G.meas_round)		
		, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,  t.mnc,  t.meas_round,  t.Date_Reporting,  t.Week_Reporting,  t.entidad,  t.Report_Type, t.Aggr_Type,
		t.ASideDevice, t.BSideDevice, t.SWVersion--, t.Youtube_Version, t.url--, t.Region_VF, t.Region_OSP

	-------------
	insert into [dbo].[_RI_Data_Ejecucion]
	select 'Fin 1.5. Insert Estadisticos 3GOnly_4G y 3GOnly_Roads - DL/UL/WEB/YTB', getdate()