insert into _RI_Data_e 
	select  
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment,t.mnc,t.meas_round,t.Date_Reporting as meas_date,t.Week_Reporting as meas_week, 
		'3GOnly_3G' as meas_Tech, 'CE_DL' as Test_type, 'Downlink' as Direction, t.entidad as vf_entity,t.Report_Type,t.Aggr_Type,
	
		-- General:
		sum(t.navegaciones) as Num_tests,
		sum(t.[fallos de acceso]) as Failed,
		sum(t.[fallos de descarga]) as Dropped,
		sum(t.[SessionTime]*t.navegaciones) as Session_time_Num,
		--sum(t.[tiempo de descarga]*t.count_throughput) as Session_time_Num,	-- SESSION_TIME de DL/UL, calculado como TRANSFER_TIME - se haría el cambio al calculo correcto en cambio de metodología para evitar salto de valor en QLIK.
		sum(t.count_throughput) as Throughput_Den,
		sum(t.navegaciones) as Session_time_Den,
		--sum(t.count_throughput) as Session_time_Den,
		sum(t.Throughput*t.count_throughput) as Throughput_Num,
		max(t.[Throughput Max]) as Throughput_Max,
		sum(t.Count_Throughput_3M) as Throughput_3M_Num,
		sum(t.Count_Throughput_1M) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(t.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(t.Throughput_ALL*t.Count_Throughput_ALL) as Throughput_with_Error_Num,

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
		sum(t.navegaciones*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,				-- Se usaria solo en NoCA_Device
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(t.navegaciones*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+
							isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,	-- Se usaria solo en NoCA_Device
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
		sum(0) as [3G_%_SF22_Num],		sum(0) as [3G_%_SF22andSF42_Num],		sum(0) as [3G_%_SF4_Num],		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],		sum(0) as [3G_%_SF22andSF42_Den],		sum(0) as [3G_%_SF4_Den],		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],	sum(0) as [3G_%_TTI2ms_Den],

		-- Ambos:
		sum(tel.[RSCP_Lin]*tel.[Count_RSCP_Lin]) as [RSCP_Lin_Num],
		sum(tel.[EcI0_Lin]*tel.[Count_EcI0_Lin]) as [EcI0_Lin_Num],	
		sum(tel.[Count_RSCP_Lin]) as [RSCP_Lin_Den],	
		sum(tel.[Count_EcI0_Lin]) as [EcI0_Lin_Den],	

		-- Performance:
		-- Solo en DL:
		sum(pfl.CQI*(isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) [3G_CQI],
		sum((isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) as [3G_DataStats_Den],
		Sum(pfl.CQI_U900*isnull(pfl.count_cqi_u900,0)) as CQI_U900_Num,
		sum(isnull(pfl.count_cqi_u900,0)) as CQI_U900_Den,
		Sum(pfl.CQI_U2100*isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Num,
		sum(isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Den,

		-- Ambos:
		sum(pfl.[HSPA_PCT]*pfl.[Count_HSPA]) as [HSPA_PCT_Num],
		sum(pfl.[HSPA+_PCT]*pfl.[Count_HSPA+]) as [HSPA+_PCT_Num],
		sum(pfl.[HSPA+_DC_PCT]*pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Num],
		sum(pfl.[Count_HSPA]) as [HSPA_PCT_Den],
		sum(pfl.[Count_HSPA+]) as [HSPA+_PCT_Den],
		sum(pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Den],

		sum(pfl.[UL_Inter_Lin]*pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Num],
		sum(pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Den],	
		
		-- Performance LTE:
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

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs:
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:
		sum(t.[ 0-0.75Mbps_N ]) as [1_N],		sum(t.[ 0.75-1.5Mbps_N ]) as [2_N],		sum(t.[ 1.5-2.25Mbps_N ]) as [3_N],
		sum(t.[ 2.25-3Mbps_N ]) as [4_N],		sum(t.[ 3-3.75Mbps_N ]) as [5_N],		sum(t.[ 3.75-4.5Mbps_N ]) as [6_N],
		sum(t.[ 4.5-5.25Mbps_N ]) as [7_N],		sum(t.[ 5.25-6Mbps_N ]) as [8_N],		sum(t.[ 6-6.75Mbps_N ]) as [9_N],
		sum(t.[ 6.75-7.5Mbps_N ]) as [10_N],	sum(t.[ 7.5-8.25Mbps_N ]) as [11_N],	sum(t.[ 8.25-9Mbps_N ]) as [12_N],
		sum(t.[ 9-9.75Mbps_N ]) as [13_N],		sum(t.[ 9.75-10.5Mbps_N ]) as [14_N],	sum(t.[ 10.5-11.25Mbps_N ]) as [15_N],
		sum(t.[ 11.25-12Mbps_N ]) as [16_N],	sum(t.[ 12-12.75Mbps_N ]) as [17_N],	sum(t.[ 12.75-13.5Mbps_N ]) as [18_N],
		sum(t.[ 13.5-14.25Mbps_N ]) as [19_N],	sum(t.[ 14.25-15Mbps_N ]) as [20_N],	sum(t.[ 15-15.75Mbps_N ]) as [21_N],
		sum(t.[ 15.75-16.5Mbps_N ]) as [22_N],	sum(t.[ 16.5-17.25Mbps_N ]) as [23_N],	sum(t.[ 17.25-18Mbps_N ]) as [24_N],
		sum(t.[ 18-18.75Mbps_N ]) as [25_N],	sum(t.[ 18.75-19.5Mbps_N ]) as [26_N],	sum(t.[ 19.5-20.25Mbps_N ]) as [27_N],
		sum(t.[ 20.25-21Mbps_N ]) as [28_N],	sum(t.[ 21-21.75Mbps_N ]) as [29_N],	sum(t.[ 21.75-22.5Mbps_N ]) as [30_N],
		sum(t.[ 22.5-23.25Mbps_N ]) as [31_N],	sum(t.[ 23.25-24Mbps_N ]) as [32_N],	sum(t.[ 24-24.75Mbps_N ]) as [33_N],
		sum(t.[ 24.75-25.5Mbps_N ]) as [34_N],	sum(t.[ 25.5-26.25Mbps_N ]) as [35_N],	sum(t.[ 26.25-27Mbps_N ]) as [36_N],
		sum(t.[ 27-27.75Mbps_N ]) as [37_N],	sum(t.[ 27.75-28.5Mbps_N ]) as [38_N],	sum(t.[ 28.5-29.25Mbps_N ]) as [39_N],
		sum(t.[ 29.25-30Mbps_N ]) as [40_N],	sum(t.[ 30-30.75Mbps_N ]) as [41_N],	sum(t.[ 30.75-31.5Mbps_N ]) as [42_N],
		sum(t.[ 31.5-32.25Mbps_N ]) as [43_N],	sum(t.[ 32.25-33Mbps_N ]) as [44_N],	sum(t.[ >33Mbps_N]) as [45_N],
		null as [46_N],	null as [47_N],	null as [48_N],	null as [49_N],	null as [50_N],	null as [51_N],	null as [52_N],	null as [53_N],	null as [54_N],	null as [55_N],
		null as [56_N],	null as [57_N],	null as [58_N],	null as [59_N],	null as [60_N],	null as [61_N],	null as [62_N],	null as [63_N],	null as [64_N],	null as [65_N],
		null as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(t.[ 0-1Mbps]) as [1]		,sum(t.[ 1-2Mbps]) as [2]		,sum(t.[ 2-3Mbps]) as [3]		,sum(t.[ 3-4Mbps]) as [4]		,sum(t.[ 4-5Mbps]) as [5]
		,sum(t.[ 5-6Mbps]) as [6]		,sum(t.[ 6-7Mbps]) as [7]		,sum(t.[ 7-8Mbps]) as [8]		,sum(t.[ 8-9Mbps]) as [9]		,sum(t.[ 9-10Mbps]) as [10]
		,sum(t.[ 10-11Mbps]) as [11]	,sum(t.[ 11-12Mbps]) as [12]	,sum(t.[ 12-13Mbps]) as [13]	,sum(t.[ 13-14Mbps]) as [14]	,sum(t.[ 14-15Mbps]) as [15]
		,sum(t.[ 15-16Mbps]) as [16]	,sum(t.[ 16-17Mbps]) as [17]	,sum(t.[ 17-18Mbps]) as [18]	,sum(t.[ 18-19Mbps]) as [19]	,sum(t.[ 19-20Mbps]) as [20]
		,sum(t.[ 20-21Mbps]) as [21]	,sum(t.[ 21-22Mbps]) as [22]	,sum(t.[ 22-23Mbps]) as [23]	,sum(t.[ 23-24Mbps]) as [24]	,sum(t.[ 24-25Mbps]) as [25]
		,sum(t.[ 25-26Mbps]) as [26]	,sum(t.[ 26-27Mbps]) as [27]	,sum(t.[ 27-28Mbps]) as [28]	,sum(t.[ 28-29Mbps]) as [29]	,sum(t.[ 29-30Mbps]) as [30]
		,sum(t.[ 30-31Mbps]) as [31]	,sum(t.[ 31-32Mbps]) as [32]	,sum(t.[ >32Mbps]) as [33]
		,null as [34]	,null as [35]	,null as [36]	,null as [37]	,null as [38]	,null as [39]	,null as [40]	,null as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from	[AGGRData3G].dbo.[lcc_aggr_sp_MDD_Data_DL_Thput_CE] t
				left outer join [AGGRData3G].[dbo].[lcc_aggr_sp_MDD_Data_DL_Performance_CE_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round 
				left outer join [AGGRData3G].[dbo].[lcc_aggr_sp_MDD_Data_DL_Technology_CE_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round
			, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,
		t.mnc,t.meas_round,t.Date_Reporting,t.Week_Reporting,t.entidad,t.Report_Type,t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP

	-------------	
	union all 
	select   
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment,t.mnc,t.meas_round,t.Date_Reporting as meas_date,t.Week_Reporting as meas_week, 
		'3GOnly_3G' as meas_Tech, 'NC_DL' as Test_type, 'Downlink' as Direction, t.entidad as vf_entity,t.Report_Type,t.Aggr_Type,
		
		-- General:
		sum(t.navegaciones) as Num_tests,
		sum(t.[fallos de acceso]) as Failed,
		sum(t.[fallos de descarga]) as Dropped,
		sum(0) as Session_time_Num,
		sum(t.count_throughput) as Throughput_Den,
		sum(0) as Session_time_Den,
		sum(t.Throughput*t.count_throughput) as Throughput_Num,
		max(t.[Throughput Max]) as Throughput_Max,
		sum(t.Count_Throughput_3M) as Throughput_3M_Num,
		sum(t.Count_Throughput_1M) as Throughput_1M_Num,
		sum(t.Count_Throughput_128k) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(t.Count_Throughput_384k) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(t.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(t.Throughput_ALL*t.Count_Throughput_ALL) as Throughput_with_Error_Num,

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
		sum(t.navegaciones*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,				-- Se usaria solo en NoCA_Device
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(t.navegaciones*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+
							isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,	-- Se usaria solo en NoCA_Device
		sum(tel.[Count_%U2100]) as Radio_U2100_use_Den,
		sum(tel.[Count_%U900]) as Radio_U900_use_Den,
		sum(tel.[Count_%LTE2100]) as Radio_LTE2100_use_Den,
		sum(tel.[Count_%LTE2600]) as Radio_LTE2600_use_Den,
		sum(tel.[Count_%LTE1800]) as Radio_LTE1800_use_Den,
		sum(tel.[Count_%LTE800]) as Radio_LTE800_use_Den,

		-- Solo en DL:
		sum(tel.[% Dual Carrier]*tel.[Count_Dual_Carrier]) as [3G_DualCarrier_use_Num],	sum(tel.[Count_Dual_Carrier]) as [3G_DualCarrier_use_Den],
		sum(tel.[%DC_U2100]*tel.[Count_DC_U2100]) as [3G_DC_2100_use_Num],				sum(tel.[Count_DC_U2100]) as [3G_DC_2100_use_Den],
		sum(tel.[%DC_U900]*tel.[Count_DC_U900]) as [3G_DC_2100_use_Num],					sum(tel.[Count_DC_U900]) as [3G_DC_2100_use_Den],

		sum(tel.[Num Codes]*tel.[Count_Num_Codes]) as [3G_NumCodes_use_Num],
		sum(tel.[Count_Num_Codes]) as [3G_NumCodes_use_Den],

		sum(tel.[QPSK]*tel.[Count_QPSK]) as [3G_QPSK_use_Num],
		sum(tel.[16QAM]*tel.[Count_16QAM]) as [3G_16QAM_use_Num],
		sum(tel.[64QAM]*tel.[Count_64QAM]) as [3G_64QAM_use_Num],
		sum(tel.[Count_QPSK]) as [3G_QPSK_use_Den],
		sum(tel.[Count_16QAM]) as [3G_16QAM_use_Den],
		sum(tel.[Count_64QAM]) as [3G_64QAM_use_Den],

		-- Solo en UL:
		sum(0) as [3G_%_SF22_Num],		sum(0) as [3G_%_SF22andSF42_Num],		sum(0) as [3G_%_SF4_Num],		sum(0) as [3G_%_SF42_Num],
		sum(0) as [3G_%_SF22_Den],		sum(0) as [3G_%_SF22andSF42_Den],		sum(0) as [3G_%_SF4_Den],		sum(0) as [3G_%_SF42_Den],
		sum(0) as [3G_%_TTI2ms_Num],	sum(0) as [3G_%_TTI2ms_Den],

		-- Ambos:
		sum(tel.[RSCP_Lin]*tel.[Count_RSCP_Lin]) as [RSCP_Lin_Num],
		sum(tel.[EcI0_Lin]*tel.[Count_EcI0_Lin]) as [EcI0_Lin_Num],	
		sum(tel.[Count_RSCP_Lin]) as [RSCP_Lin_Den],	
		sum(tel.[Count_EcI0_Lin]) as [EcI0_Lin_Den],	

		-- Performance:
		-- Solo en DL:
		sum(pfl.CQI*(isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) [3G_CQI],
		sum((isnull(pfl.count_cqi_u2100,0)+isnull(pfl.count_cqi_u900,0))) as [3G_DataStats_Den],
		Sum(pfl.CQI_U900*isnull(pfl.count_cqi_u900,0)) as CQI_U900_Num,
		sum(isnull(pfl.count_cqi_u900,0)) as CQI_U900_Den,
		Sum(pfl.CQI_U2100*isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Num,
		sum(isnull(pfl.count_cqi_u2100,0)) as CQI_U2100_Den,

		-- Ambos:
		sum(pfl.[HSPA_PCT]*pfl.[Count_HSPA]) as [HSPA_PCT_Num],
		sum(pfl.[HSPA+_PCT]*pfl.[Count_HSPA+]) as [HSPA+_PCT_Num],
		sum(pfl.[HSPA+_DC_PCT]*pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Num],
		sum(pfl.[Count_HSPA]) as [HSPA_PCT_Den],
		sum(pfl.[Count_HSPA+]) as [HSPA+_PCT_Den],
		sum(pfl.[Count_HSPA+_DC]) as [HSPA+_DC_PCT_Den],

		sum(pfl.[UL_Inter_Lin]*pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Num],
		sum(pfl.[Count_UL_Inter]) as [UL_Inter_Lin_Den],	
	
		-- Performance LTE:
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

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs:
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(t.[ 0-0.75Mbps_N ]) as [1_N],		sum(t.[ 0.75-1.5Mbps_N ]) as [2_N],		sum(t.[ 1.5-2.25Mbps_N ]) as [3_N],		sum(t.[ 2.25-3Mbps_N ]) as [4_N],		sum(t.[ 3-3.75Mbps_N ]) as [5_N],
		sum(t.[ 3.75-4.5Mbps_N ]) as [6_N],		sum(t.[ 4.5-5.25Mbps_N ]) as [7_N],		sum(t.[ 5.25-6Mbps_N ]) as [8_N],		sum(t.[ 6-6.75Mbps_N ]) as [9_N],		sum(t.[ 6.75-7.5Mbps_N ]) as [10_N],
		sum(t.[ 7.5-8.25Mbps_N ]) as [11_N],	sum(t.[ 8.25-9Mbps_N ]) as [12_N],		sum(t.[ 9-9.75Mbps_N ]) as [13_N],		sum(t.[ 9.75-10.5Mbps_N ]) as [14_N],	sum(t.[ 10.5-11.25Mbps_N ]) as [15_N],
		sum(t.[ 11.25-12Mbps_N ]) as [16_N],	sum(t.[ 12-12.75Mbps_N ]) as [17_N],	sum(t.[ 12.75-13.5Mbps_N ]) as [18_N],	sum(t.[ 13.5-14.25Mbps_N ]) as [19_N],	sum(t.[ 14.25-15Mbps_N ]) as [20_N],
		sum(t.[ 15-15.75Mbps_N ]) as [21_N],	sum(t.[ 15.75-16.5Mbps_N ]) as [22_N],	sum(t.[ 16.5-17.25Mbps_N ]) as [23_N],	sum(t.[ 17.25-18Mbps_N ]) as [24_N],	sum(t.[ 18-18.75Mbps_N ]) as [25_N],
		sum(t.[ 18.75-19.5Mbps_N ]) as [26_N],	sum(t.[ 19.5-20.25Mbps_N ]) as [27_N],	sum(t.[ 20.25-21Mbps_N ]) as [28_N],	sum(t.[ 21-21.75Mbps_N ]) as [29_N],	sum(t.[ 21.75-22.5Mbps_N ]) as [30_N],
		sum(t.[ 22.5-23.25Mbps_N ]) as [31_N],	sum(t.[ 23.25-24Mbps_N ]) as [32_N],	sum(t.[ 24-24.75Mbps_N ]) as [33_N],	sum(t.[ 24.75-25.5Mbps_N ]) as [34_N],	sum(t.[ 25.5-26.25Mbps_N ]) as [35_N],
		sum(t.[ 26.25-27Mbps_N ]) as [36_N],	sum(t.[ 27-27.75Mbps_N ]) as [37_N],	sum(t.[ 27.75-28.5Mbps_N ]) as [38_N],	sum(t.[ 28.5-29.25Mbps_N ]) as [39_N],	sum(t.[ 29.25-30Mbps_N ]) as [40_N],
		sum(t.[ 30-30.75Mbps_N ]) as [41_N],	sum(t.[ 30.75-31.5Mbps_N ]) as [42_N],	sum(t.[ 31.5-32.25Mbps_N ]) as [43_N],	sum(t.[ 32.25-33Mbps_N ]) as [44_N],	sum(t.[ >33Mbps_N ]) as [45_N],
		null as [46_N],	null as [47_N],	null as [48_N],	null as [49_N],	null as [50_N],	null as [51_N],	null as [52_N],	null as [53_N],	null as [54_N],	null as [55_N],	null as [56_N],	null as [57_N],	null as [58_N],	null as [59_N],	null as [60_N],
		null as [61_N],	null as [62_N],	null as [63_N],	null as [64_N],	null as [65_N],	null as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(t.[ 0-1Mbps]) as [1]		,sum(t.[ 1-2Mbps]) as [2]		,sum(t.[ 2-3Mbps]) as [3]		,sum(t.[ 3-4Mbps]) as [4]		,sum(t.[ 4-5Mbps]) as [5]
		,sum(t.[ 5-6Mbps]) as [6]		,sum(t.[ 6-7Mbps]) as [7]		,sum(t.[ 7-8Mbps]) as [8]		,sum(t.[ 8-9Mbps]) as [9]		,sum(t.[ 9-10Mbps]) as [10]
		,sum(t.[ 10-11Mbps]) as [11]	,sum(t.[ 11-12Mbps]) as [12]	,sum(t.[ 12-13Mbps]) as [13]	,sum(t.[ 13-14Mbps]) as [14]	,sum(t.[ 14-15Mbps]) as [15]
		,sum(t.[ 15-16Mbps]) as [16]	,sum(t.[ 16-17Mbps]) as [17]	,sum(t.[ 17-18Mbps]) as [18]	,sum(t.[ 18-19Mbps]) as [19]	,sum(t.[ 19-20Mbps]) as [20]
		,sum(t.[ 20-21Mbps]) as [21]	,sum(t.[ 21-22Mbps]) as [22]	,sum(t.[ 22-23Mbps]) as [23]	,sum(t.[ 23-24Mbps]) as [24]	,sum(t.[ 24-25Mbps]) as [25]
		,sum(t.[ 25-26Mbps]) as [26]	,sum(t.[ 26-27Mbps]) as [27]	,sum(t.[ 27-28Mbps]) as [28]	,sum(t.[ 28-29Mbps]) as [29]	,sum(t.[ 29-30Mbps]) as [30]
		,sum(t.[ 30-31Mbps]) as [31]	,sum(t.[ 31-32Mbps]) as [32]	,sum(t.[ >32Mbps]) as [33]	
		,null as [34]	,null as [35]	,null as [36]	,null as [37]	,null as [38]	,null as [39]	,null as [40]	,null as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from	[AGGRData3G].dbo.[lcc_aggr_sp_MDD_Data_DL_Thput_NC] t
				left outer join [AGGRData3G].[dbo].[lcc_aggr_sp_MDD_Data_DL_Performance_NC_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round
				left outer join  [AGGRData3G].[dbo].[lcc_aggr_sp_MDD_Data_DL_Technology_NC_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round
				, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,
		t.mnc,t.meas_round,t.Date_Reporting,t.Week_Reporting,t.entidad,t.Report_Type,t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP

	-------------
	union all 
	select   
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment,t.mnc,t.meas_round,t.Date_Reporting as meas_date,t.Week_Reporting as meas_week, 
		'3GOnly_3G' as meas_Tech, 'CE_UL' as Test_type, 'Uplink' as Direction, t.entidad as vf_entity,t.Report_Type,t.Aggr_Type,
	
		-- General:
		sum(t.Subidas) as Num_tests,
		sum(t.[fallos de acceso]) as Failed,
		sum(t.[fallos de descarga]) as Dropped,
		sum(t.[SessionTime]*t.Subidas) as Session_time_Num,
		--sum(t.[Tiempo de subida]*t.count_throughput) as Session_time_Num,	-- SESSION_TIME de DL/UL, calculado como TRANSFER_TIME - se haría el cambio al calculo correcto en cambio de metodología para evitar salto de valor en QLIK.
		sum(t.count_throughput) as Throughput_Den,
		sum(t.Subidas) as Session_time_Den,
		--sum(t.count_throughput) as Session_time_Den,
		sum(t.Throughput*t.count_throughput) as Throughput_Num,
		max(t.[Throughput Max]) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(t.Count_Throughput_1M) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(0) as Throughput_64K_Num,
		sum(0) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(t.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(t.Throughput_ALL*t.Count_Throughput_ALL) as Throughput_with_Error_Num,

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
		sum(t.subidas*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,					-- Se usaria solo en NoCA_Device
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(t.subidas*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+
						isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,	-- Se usaria solo en NoCA_Device
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
		-- Solo DL:
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
	
		-- Performance LTE:
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

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs:
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:
		sum(t.[ 0-0.25Mbps_N ]) as [1_N],		sum(t.[ 0.25-0.5Mbps_N ]) as [2_N],	sum(t.[ 0.5-0.75Mbps_N ]) as [3_N],	sum(t.[ 0.75-1Mbps_N ]) as [4_N],		sum(t.[ 1-1.25Mbps_N ]) as [5_N],
		sum(t.[ 1.25-1.5Mbps_N ]) as [6_N],	sum(t.[ 1.5-1.75Mbps_N ]) as [7_N],	sum(t.[ 1.75-2Mbps_N ]) as [8_N],		sum(t.[ 2-2.25Mbps_N ]) as [9_N],		sum(t.[ 2.25-2.5Mbps_N ]) as [10_N],
		sum(t.[ 2.5-2.75Mbps_N ]) as [11_N],	sum(t.[ 2.75-3Mbps_N ]) as [12_N],	sum(t.[ 3-3.25Mbps_N ]) as [13_N],	sum(t.[ 3.25-3.5Mbps_N ]) as [14_N],	sum(t.[ 3.5-3.75Mbps_N ]) as [15_N],
		sum(t.[ 3.75-4Mbps_N ]) as [16_N],	sum(t.[ 4-4.25Mbps_N ]) as [17_N],	sum(t.[ 4.25-4.5Mbps_N ]) as [18_N],	sum(t.[ 4.5-4.75Mbps_N ]) as [19_N],	sum(t.[ 4.75-5Mbps_N ]) as [20_N],
		sum(t.[ >5Mbps_N ]) as [21_N],
		null as [22_N],	null as [23_N],	null as [24_N],	null as [25_N],	null as [26_N],	null as [27_N],	null as [28_N],	null as [29_N],	null as [30_N],
		null as [31_N],	null as [32_N],	null as [33_N],	null as [34_N],	null as [35_N],	null as [36_N],	null as [37_N],	null as [38_N],	null as [39_N],
		null as [40_N],	null as [41_N],	null as [42_N],	null as [43_N],	null as [44_N],	null as [45_N],	null as [46_N],	null as [47_N],	null as [48_N],
		null as [49_N],	null as [50_N],	null as [51_N],	null as [52_N],	null as [53_N],	null as [54_N],	null as [55_N],	null as [56_N],	null as [57_N],
		null as [58_N],	null as [59_N],	null as [60_N],	null as [61_N],	null as [62_N],	null as [63_N],	null as [64_N],	null as [65_N],	null as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(t.[ 0-0.5Mbps]) as [1]		,sum(t.[ 0.5-1Mbps]) as [2]		,sum(t.[ 1-1.5Mbps]) as [3]		,sum(t.[ 1.5-2Mbps]) as [4]		,sum(t.[ 2-2.5Mbps]) as [5]
		,sum(t.[ 2.5-3Mbps]) as [6]		,sum(t.[ 3-3.5Mbps]) as [7]		,sum(t.[ 3.5-4Mbps]) as [8]		,sum(t.[ 4-4.5Mbps]) as [9]		,sum(t.[ 4.5-5Mbps]) as [10]
		,sum(t.[ >5Mbps]) as [11]
		,null as [12]	,null as [13]	,null as [14]	,null as [15]	,null as [16]	,null as [17]	,null as [18]	,null as [19]	,null as [20]
		,null as [21]	,null as [22]	,null as [23]	,null as [24]	,null as [25]	,null as [26]	,null as [27]	,null as [28]	,null as [29]
		,null as [30]	,null as [31]	,null as [32]	,null as [33]	,null as [34]	,null as [35]	,null as [36]	,null as [37]	,null as [38]
		,null as [39]	,null as [40]	,null as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from	[AGGRData3G].dbo.[lcc_aggr_sp_MDD_Data_UL_Thput_CE] t
				left outer join [AGGRData3G].[dbo].[lcc_aggr_sp_MDD_Data_UL_Performance_CE_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round
				left outer join  [AGGRData3G].[dbo].[lcc_aggr_sp_MDD_Data_UL_Technology_CE_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round
				, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,
		t.mnc,t.meas_round,t.Date_Reporting,t.Week_Reporting,t.entidad,t.Report_Type,t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP

	-------------
	union all 
	select   
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end vf_environment,t.mnc,t.meas_round,t.Date_Reporting as meas_date,t.Week_Reporting as meas_week, 
		'3GOnly_3G' as meas_Tech, 'NC_UL' as Test_type, 'Uplink' as Direction, t.entidad as vf_entity,t.Report_Type,t.Aggr_Type,
	
		-- General:
		sum(t.Subidas) as Num_tests,
		sum(t.[fallos de acceso]) as Failed,
		sum(t.[fallos de descarga]) as Dropped,
		sum(0) as Session_time_Num,
		sum(t.count_throughput) as Throughput_Den,
		sum(0) as Session_time_Den,
		sum(t.Throughput*t.count_throughput) as Throughput_Num,
		max(t.[Throughput Max]) as Throughput_Max,
		sum(0) as Throughput_3M_Num,
		sum(t.Count_Throughput_1M) as Throughput_1M_Num,
		sum(0) as Throughput_128K_Num,
		sum(t.Count_Throughput_64k) as Throughput_64K_Num,
		sum(t.Count_Throughput_384k) as Throughput_384K_Num,
		--CAC 10/08/2017: thput de test sin error y con error
		sum(t.Count_Throughput_ALL) as Throughput_with_Error_Den,
		sum(t.Throughput_ALL*t.Count_Throughput_ALL) as Throughput_with_Error_Num,

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
		sum(t.Subidas*(isnull(tel.[% GSM],0)+isnull(tel.[% WCDMA],0)+isnull(tel.[% LTE],0))) as Radio_use_Den,						-- Se usaria solo en NoCA_Device
		sum(tel.[Count_%GSM]) as Radio_2G_use_Den,
		sum(tel.[Count_%WCDMA]) as Radio_3G_use_Den,
		sum(tel.[Count_%LTE]) as Radio_4G_use_Den,

		sum(tel.[% U2100]*tel.[Count_%U2100]) as Radio_U2100_use_Num,
		sum(tel.[% U900]*tel.[Count_%U900]) as Radio_U900_use_Num,
		sum(tel.[% LTE2100]*tel.[Count_%LTE2100]) as Radio_LTE2100_use_Num,
		sum(tel.[% LTE2600]*tel.[Count_%LTE2600]) as Radio_LTE2600_use_Num,
		sum(tel.[% LTE1800]*tel.[Count_%LTE1800]) as Radio_LTE1800_use_Num,
		sum(tel.[% LTE800]*tel.[Count_%LTE800]) as Radio_LTE800_use_Num,
		sum(t.Subidas*(isnull(tel.[% U2100],0)+isnull(tel.[% U900],0)+isnull(tel.[% LTE2100],0)+
						isnull(tel.[% LTE2600],0)+isnull(tel.[% LTE1800],0)+isnull(tel.[% LTE800],0))) as Radio_Band_Use_Den,		-- Se usaria solo en NoCA_Device
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
		sum(1.0*tel.[% TTI 2ms_float]*tel.[Count_%TTI_2ms]) as [3G_%_TTI2ms_Num],
		sum(tel.[Count_%TTI_2ms]) as [3G_%_TTI2ms_Den],	
	
		sum(tel.[RSCP_Lin]*tel.[Count_RSCP_Lin]) as [RSCP_Lin_Num],
		sum(tel.[EcI0_Lin]*tel.[Count_EcI0_Lin]) as [EcI0_Lin_Num],	
		sum(tel.[Count_RSCP_Lin]) as [RSCP_Lin_Den],	
		sum(tel.[Count_EcI0_Lin]) as [EcI0_Lin_Den],
			
		-- Performance:
		-- Solo DL:
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
	
		-- Performance LTE:
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

		-- Technology LTE:
		sum(0) as [4G_%CA_Num],			sum(0) as [4G_%CA_Den],	
		sum(0) as [4G_BPSK_Use_Num],	sum(0) as [4G_QPSK_Use_Num],	sum(0) as [4G_16QAM_Use_Num],    sum(0) as [4G_64QAM_Use_Num],
		sum(0) as [4G_BPSK_Use_Den],	sum(0) as [4G_QPSK_Use_Den],	sum(0) as [4G_16QAM_Use_Den],    sum(0) as [4G_64QAM_Use_Den],

		sum(0) as [4G_stats_Den],

		sum(0) as [RSRP_Lin_Num],	sum(0) as [RSRQ_Lin_Num],	sum(0) as [SINR_Lin_Num],			
		sum(0) as [RSRP_Lin_Den],	sum(0) as [RSRQ_Lin_Den],	sum(0) as [SINR_Lin_Den],			

		--New KPIs:
		sum(0) as [MIMO_num],	sum(0) as [RI1_num],	sum(0) as [RI2_num],
		sum(0) as [MIMO_den],	sum(0) as [RI1_den],	sum(0) as [RI2_den],
		sum(0) as RBs_Allocated_Den,	sum(0) as RBs_Allocated_Num,	max(0) as RBs_Allocated_Max,

		-- Rangos Nuevos - el nombre del rango se reuitilizara en los rangos de thput 3G/4G y en las latencias:	
		sum(t.[ 0-0.25Mbps_N ]) as [1_N],		sum(t.[ 0.25-0.5Mbps_N ]) as [2_N],	sum(t.[ 0.5-0.75Mbps_N ]) as [3_N],	sum(t.[ 0.75-1Mbps_N ]) as [4_N],		sum(t.[ 1-1.25Mbps_N ]) as [5_N],
		sum(t.[ 1.25-1.5Mbps_N ]) as [6_N],	sum(t.[ 1.5-1.75Mbps_N ]) as [7_N],	sum(t.[ 1.75-2Mbps_N ]) as [8_N],		sum(t.[ 2-2.25Mbps_N ]) as [9_N],		sum(t.[ 2.25-2.5Mbps_N ]) as [10_N],
		sum(t.[ 2.5-2.75Mbps_N ]) as [11_N],	sum(t.[ 2.75-3Mbps_N ]) as [12_N],	sum(t.[ 3-3.25Mbps_N ]) as [13_N],	sum(t.[ 3.25-3.5Mbps_N ]) as [14_N],	sum(t.[ 3.5-3.75Mbps_N ]) as [15_N],
		sum(t.[ 3.75-4Mbps_N ]) as [16_N],	sum(t.[ 4-4.25Mbps_N ]) as [17_N],	sum(t.[ 4.25-4.5Mbps_N ]) as [18_N],	sum(t.[ 4.5-4.75Mbps_N ]) as [19_N],	sum(t.[ 4.75-5Mbps_N ]) as [20_N],
		sum(t.[ >5Mbps_N ]) as [21_N],
		null as [22_N],	null as [23_N],	null as [24_N],	null as [25_N],	null as [26_N],	null as [27_N],	null as [28_N],	null as [29_N],	null as [30_N],	null as [31_N],	null as [32_N],	null as [33_N],	null as [34_N],	null as [35_N],
		null as [36_N],	null as [37_N],	null as [38_N],	null as [39_N],	null as [40_N],	null as [41_N],	null as [42_N],	null as [43_N],	null as [44_N],	null as [45_N],	null as [46_N],	null as [47_N],	null as [48_N],	null as [49_N],
		null as [50_N],	null as [51_N],	null as [52_N],	null as [53_N],	null as [54_N],	null as [55_N],	null as [56_N],	null as [57_N],	null as [58_N],	null as [59_N],	null as [60_N],	null as [61_N],	null as [62_N],	null as [63_N],
		null as [64_N],	null as [65_N],	null as [66_N]
	
		--null as Region_Road_VF, null as Region_Road_OSP,
		--t.Region_VF as Region_VF, t.Region_OSP as Region_OSP

		-- Rangos Antiguos - necesario para entidades antiguas que tienen otro calculo
		,sum(t.[ 0-0.5Mbps]) as [1]		,sum(t.[ 0.5-1Mbps]) as [2]		,sum(t.[ 1-1.5Mbps]) as [3]		,sum(t.[ 1.5-2Mbps]) as [4]		,sum(t.[ 2-2.5Mbps]) as [5]
		,sum(t.[ 2.5-3Mbps]) as [6]		,sum(t.[ 3-3.5Mbps]) as [7]		,sum(t.[ 3.5-4Mbps]) as [8]		,sum(t.[ 4-4.5Mbps]) as [9]		,sum(t.[ 4.5-5Mbps]) as [10]
		,sum(t.[ >5Mbps]) as [11]
		,null as [12]	,null as [13]	,null as [14]	,null as [15]	,null as [16]	,null as [17]	,null as [18]	,null as [19]	,null as [20]
		,null as [21]	,null as [22]	,null as [23]	,null as [24]	,null as [25]	,null as [26]	,null as [27]	,null as [28]	,null as [29]
		,null as [30]	,null as [31]	,null as [32]	,null as [33]	,null as [34]	,null as [35]	,null as [36]	,null as [37]	,null as [38]
		,null as [39]	,null as [40]	,null as [41],

		-- Parametros de configuracion:
		pfl.ASideDevice as ASideDevice, pfl.BSideDevice as BSideDevice, pfl.SWVersion as SWVersion, 
		null as YTB_Version, null as YTB_URL

	from	[AGGRData3G].dbo.[lcc_aggr_sp_MDD_Data_UL_Thput_NC] t
				left outer join [AGGRData3G].[dbo].[lcc_aggr_sp_MDD_Data_UL_Performance_NC_3G] pfl
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(pfl.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=pfl.mnc and t.Date_Reporting=pfl.Date_Reporting and t.entidad=pfl.entidad and t.Aggr_Type=pfl.Aggr_Type and t.Report_Type=pfl.Report_Type and t.meas_round=pfl.meas_round
				left outer join  [AGGRData3G].[dbo].[lcc_aggr_sp_MDD_Data_UL_Technology_NC_3G] tel
				on isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(tel.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=tel.mnc and t.Date_Reporting=tel.Date_Reporting and t.entidad=tel.entidad and t.Aggr_Type=tel.Aggr_Type and t.Report_Type=tel.Report_Type and t.meas_round=tel.meas_round 
				, agrids.dbo.vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,t.mnc,t.meas_round,t.Date_Reporting,t.Week_Reporting,t.entidad,t.Report_Type,t.Aggr_Type,
		pfl.ASideDevice, pfl.BSideDevice, pfl.SWVersion--, t.Region_VF, t.Region_OSP