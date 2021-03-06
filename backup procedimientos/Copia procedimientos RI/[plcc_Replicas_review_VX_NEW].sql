USE [QLIK]
GO
/****** Object:  StoredProcedure [dbo].[plcc_Replicas_review_VX]    Script Date: 13/07/2017 16:31:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[plcc_Replicas_review_VX]
	 @environment as varchar(50)
	,@BBDD as varchar(50)
	,@tablename as varchar(250)
	,@TypeMeas as nvarchar(50)
	,@last_measurement as nvarchar(50)
	,@RollWindow as int
as

----------- VARIABLES PARA PRUEBAS ----------------------------
---- DATOS:
--declare @environment as nvarchar(50) ='AVE'
--declare @BBDD as varchar(50) = 'AddedValue'
--declare @tablename as nvarchar(50) = '_RI_Data_last'
--declare @TypeMeas as nvarchar(50) = 'Data'
--declare @last_measurement as nvarchar(50) = 'last_measurement_vdf'
--declare @RollWindow as int = 3

----exec [QLIK].dbo.plcc_Replicas_review_VX 'AVE','AddedValue','_RI_Data_v18_last','Data', @last_measurement, @rollwindowAve

---- VOZ:
--declare @environment as nvarchar(50) ='AVE'
--declare @BBDD as varchar(50) = 'AddedValue'
--declare @tablename as nvarchar(50) = '_RI_Voice_V21_last'
--declare @TypeMeas as nvarchar(50) = 'Voice'
--declare @last_measurement as nvarchar(50) = 'last_measurement_vdf'
--declare @RollWindow as int = 3

----exec [QLIK].dbo.plcc_Replicas_review_VX 'AVE','AddedValue','_RI_Voice_last','Voice', @last_measurement, @rollwindow


---------------------------------------------------------------
declare @meas_tech as nvarchar(50)
declare @id as varchar(50)
declare @version as varchar(50)
declare @report as varchar(50)
declare @reportVDF as varchar(50)

-- Asignamos la coletilla final a las tablas finales e inet
if master.dbo.fn_lcc_getElement(4,@tablename,'_') like 'v%'
begin
	set @version='_RI_'+@TypeMeas+'_'+master.dbo.fn_lcc_getElement(4,@tablename,'_')
end
else
begin
	set @version='_RI_'+@TypeMeas
end

---------------------------------------------
-- Declaracion de mas variables:
If  @environment = 'AVE'
BEGIN
	 set @meas_tech = '%4G%'
END
else
BEGIN	  
	  set @meas_tech = '%Road 4G%'
END

---------------------------------------------
If @last_measurement = 'last_measurement_vdf'
BEGIN
	set @id = 'id_vdf'
	set @report='VDF'
	set @reportVDF='NULL'
END
ELSE
BEGIN
	set @id = 'id_osp'
	set @report='MUN'
	set @reportVDF='VDF'
END


---------------------------------------------------------------
----------- BORRAMOS TODAS LAS TABLAS SI EXISTIERAN -----------

exec('exec QLIK.dbo.sp_lcc_dropifexists ''_null_review'+@version+'''')
exec('exec QLIK.dbo.sp_lcc_dropifexists ''_min_round_null_review'+@version+'''')
exec('exec QLIK.dbo.sp_lcc_dropifexists ''_replicas_review'+@version+'''')
exec('exec QLIK.dbo.sp_lcc_dropifexists ''_Completed_review'+@version+'''')
---------------------------------------------------------------


--drop table _null_review
If @TypeMeas = 'Data'
BEGIN

exec('


--****************************************************************************
--	1. Sacamos los nulos, que serán las medidas que haya que rellenar---------
--****************************************************************************

select a.entity,a.test_type,a.report_type,a.round,a.operator,b.environment,a.meas_tech,a.meas_date,a.meas_week,a.'+@last_measurement+' 

into _null_review'+@version+'

from
(Select a.*, b.operator

from (
Select distinct(entity),test_type,report_type,round,'+@last_measurement+' ,meas_tech,meas_date,meas_week
from '+@BBDD+'.dbo.'+@tablename+'  
where  '+@last_measurement+' <> 0 and operator = ''Vodafone'' and environment = '''+@environment+'''and meas_tech like '''+@meas_tech+''' and test_type not in (''Youtube SD''/*,''Ping''*/))a,

(select operator from '+@BBDD+'.dbo.'+@tablename+' group by operator) b


) a

left outer join 

( Select * from '+@BBDD+'.dbo.'+@tablename+' b where b.'+@last_measurement+' <> 0 and b.environment = '''+@environment+'''and meas_tech like '''+@meas_tech+'''  and b.test_type not in (''Youtube SD''/*,''Ping''*/) ) b

 on (a.entity=b.entity and a.test_type=b.test_type and a.operator=b.operator and a.report_type=b.report_type and a.round=b.round
     and a.meas_tech = b.meas_tech and a.meas_date=b.meas_date and a.meas_week=b.meas_week)
 where environment is null 
 

--****************************************************************************
--	2. Detectamos la vuelta más reciente a rellenar si hubiese más de una----------
--****************************************************************************

Select n.entity,n.test_type,n.report_type,n.round,n.operator,n.meas_tech,n.meas_date,n.meas_week,m.meas_min

into _min_round_null_review'+@version+'

from _null_review'+@version+' n

left join

 (Select entity, test_type,report_type, operator,meas_tech,min('+@last_measurement+' ) as meas_min from _null_review'+@version+' group by entity, test_type,report_type,operator,meas_tech) m

on (n.entity=m.entity and n.test_type=m.test_type and n.report_type=m.report_type and n.operator=m.operator
    and n.'+@last_measurement+'  = m.meas_min and n.meas_tech=m.meas_tech)

 where m.meas_min is not null


--****************************************************************************
--	3. Detectamos la última vuelta válida para cada una de las entidades con NULOS---------
--****************************************************************************
Select 
	l.[codigo_ine],	l.[environment],	
	mrn.[operator],	
	l.[mnc],	l.[meas_round],	
	mrn.[meas_date],	mrn.[meas_week],	mrn.[meas_Tech],	mrn.[test_type],	
	l.[Direction],	
	mrn.[Report_Type],	
	l.[id_osp],	l.[id_vdf],	l.[id_osp_noComp],	
	mrn.[entity],	mrn.[Round],	
	l.[Poblacion],[Num_tests] ,[Failed],[Dropped],[Session_time_Num],[Throughput_Den],[Session_time_Den],[Throughput_Num],[Throughput_Max]
    ,[Throughput_3M_Num],[Throughput_1M_Num],[Throughput_128K_Num],[Throughput_64K_Num],[Throughput_384K_Num],[WEB_IP_ACCESS_TIME_NUM]
    ,[WEB_IP_ACCESS_TIME_DEN],[WEB_HTTP_TRANSFER_TIME_NUM],[WEB_HTTP_TRANSFER_TIME_DEN],[WEB_IP_ACCESS_TIME_HTTPS_NUM]
    ,[WEB_IP_ACCESS_TIME_HTTPS_DEN],[WEB_TRANSFER_TIME_HTTPS_NUM],[WEB_TRANSFER_TIME_HTTPS_DEN],[WEB_IP_ACCESS_TIME_PUBLIC_NUM]
    ,[WEB_IP_ACCESS_TIME_PUBLIC_DEN],[WEB_TRANSFER_TIME_PUBLIC_NUM],[WEB_TRANSFER_TIME_PUBLIC_DEN],[Radio_2G_use_Num]
    ,[Radio_3G_use_Num],[Radio_4G_use_Num],[Radio_use_Den],[Radio_2G_use_Den],[Radio_3G_use_Den],[Radio_4G_use_Den]
    ,[Radio_U2100_use_Num],[Radio_U900_use_Num],[Radio_LTE2100_use_Num],[Radio_LTE2600_use_Num],[Radio_LTE1800_use_Num],[Radio_Band_Use_Den]
    ,[Radio_U2100_use_Den],[Radio_U900_use_Den],[Radio_LTE2100_use_Den],[Radio_LTE2600_use_Den],[Radio_LTE1800_use_Den],[Radio_LTE800_use_Den]
    ,[3G_DualCarrier_use_Num],[3G_DualCarrier_use_Den],[3G_DC_2100_use_Num],[3G_DC_2100_use_Den],[3G_DC_900_use_Num],[3G_DC_900_use_Den]
    ,[3G_NumCodes_use_Num],[3G_NumCodes_use_Den],[3G_QPSK_use_Num],[3G_16QAM_use_Num],[3G_64QAM_use_Num],[3G_QPSK_use_Den],[3G_16QAM_use_Den]
    ,[3G_64QAM_use_Den],[3G_%_SF22_Num],[3G_%_SF22andSF42_Num],[3G_%_SF4_Num],[3G_%_SF42_Num]
    ,[3G_%_SF22_Den],[3G_%_SF22andSF42_Den],[3G_%_SF4_Den],[3G_%_SF42_Den],[3G_%_TTI2ms_Num],[3G_%_TTI2ms_Den]
    ,[RSCP_Lin_Num],[EcI0_Lin_Num],[RSCP_Lin_Den],[EcI0_Lin_Den],[3G_CQI],[3G_DataStats_Den],[CQI_U900_Num],[CQI_U900_Den]
    ,[CQI_U2100_Num],[CQI_U2100_Den],[HSPA_PCT_Num],[HSPA+_PCT_Num],[HSPA+_DC_PCT_Num],[HSPA_PCT_Den],[HSPA+_PCT_Den]
    ,[HSPA+_DC_PCT_Den],[UL_Inter_Lin_Num],[UL_Inter_Lin_Den]
    ,[CQI_4G_Num],[CQI_L800_Num],[CQI_L1800_Num],[CQI_L2100_Num],[CQI_L2600_Num],[CQI_4G_Den],[CQI_L800_Den],[CQI_L1800_Den]
    ,[CQI_L2100_Den],[CQI_L2600_Den],[LTE_5Mhz_SC_Use_Num],[LTE_10Mhz_SC_Use_Num],[LTE_15Mhz_SC_Use_Num],[LTE_20Mhz_SC_Use_Num]
	,[LTE_15Mhz_CA_Use_Num],[LTE_20Mhz_CA_Use_Num],[LTE_25Mhz_CA_Use_Num],[LTE_30Mhz_CA_Use_Num]
    ,[LTE_35Mhz_CA_Use_Num],[LTE_40Mhz_CA_Use_Num],[LTE_5Mhz_SC_Use_Den]
    ,[LTE_10Mhz_SC_Use_Den],[LTE_15Mhz_SC_Use_Den],[LTE_20Mhz_SC_Use_Den],[LTE_15Mhz_CA_Use_Den],[LTE_20Mhz_CA_Use_Den]
    ,[LTE_25Mhz_CA_Use_Den],[LTE_30Mhz_CA_Use_Den],[LTE_35Mhz_CA_Use_Den],[LTE_40Mhz_CA_Use_Den]
    ,[LTE_BW_use_den],[4G_RBs_use_Num],[4G_RBs_use_Den],[4G_TM1_use_Num],[4G_TM2_use_Num],[4G_TM3_use_Num]
    ,[4G_TM4_use_Num],[4G_TM5_use_Num],[4G_TM6_use_Num],[4G_TM7_use_Num],[4G_TM8_use_Num]
    ,[4G_TM9_use_Num],[4G_TMInvalid_use_Num],[4G_TMUnknown_use_Num],[4G_TM_Den],[4G_%CA_Num]
    ,[4G_%CA_Den],[4G_BPSK_Use_Num],[4G_QPSK_Use_Num],[4G_16QAM_Use_Num],[4G_64QAM_Use_Num],[4G_BPSK_Use_Den],[4G_QPSK_Use_Den]
    ,[4G_16QAM_Use_Den],[4G_64QAM_Use_Den],[4G_stats_Den],[RSRP_Lin_Num],[RSRQ_Lin_Num]
    ,[SINR_Lin_Num],[RSRP_Lin_Den],[RSRQ_Lin_Den],[SINR_Lin_Den],[MIMO_num],[RI1_num]
    ,[RI2_num],[MIMO_den],[RI1_den],[RI2_den]
    ,[RBs_Allocated_Den],[RBs_Allocated_Num],[4G_RBs_Allocated_Max]
    ,[1_N],[2_N],[3_N],[4_N],[5_N],[6_N],[7_N],[8_N],[9_N],[10_N],[11_N],[12_N],[13_N],[14_N],[15_N],[16_N],[17_N],[18_N],[19_N]
    ,[20_N],[21_N],[22_N],[23_N],[24_N],[25_N],[26_N],[27_N],[28_N],[29_N],[30_N],[31_N],[32_N],[33_N],[34_N],[35_N],[36_N]
    ,[37_N],[38_N],[39_N],[40_N],[41_N],[42_N],[43_N],[44_N],[45_N],[46_N],[47_N],[48_N],[49_N],[50_N],[51_N],[52_N],[53_N]
    ,[54_N],[55_N],[56_N],[57_N],[58_N],[59_N],[60_N],[61_N],[62_N],[63_N],[64_N],[65_N],[66_N]
	,[1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24],[25],[26]
    ,[27],[28],[29],[30],[31],[32],[33],[34],[35],[36],[37],[38],[39],[40],[41],[Latency_num],[Latency_den],[Methodology],[Avg_Video_StarTime_Num]
    ,[Avg_Video_startTime_Den],[Reproductions_WO_Interruptions],[Reproductions_WO_Interruptions_Den],[HD_reproduction_rate_num]
    ,[HD_reproduction_rate_den],[YTB_video_resolution_num],[YTB_video_resolution_den],[YTB_video_mos_num],[YTB_video_mos_den],[YTB_url]
    ,[B4],[ReproduccionesHD],[Successful video download],[Reproducciones],[YTB_1st_Resolution_Num],[YTB_1st_Resolution_Den]
    ,[YTB_2nd_Resolution_Num],[YTB_2nd_Resolution_Den],[YTB_FirstChangeFromInit_Num],[YTB_FirstChangeFromInit_Den],[YTB_initialResolution_Num]
    ,[YTB_initialResolution_Den],[YTB_finalResolution_Num],[YTB_finalResolution_Den],[YTB_video_resolution_144p_Num]
    ,[YTB_video_resolution_144p_Den],[YTB_video_mos_144p_Num],[YTB_video_mos_144p_Den],[YTB_video_resolution_%144p_Num]
    ,[YTB_video_resolution_%144p_Den],[YTB_video_resolution_240p_Num],[YTB_video_resolution_240p_Den],[YTB_video_mos_240p_Num],[YTB_video_mos_240p_Den]
    ,[YTB_video_resolution_%240p_Num],[YTB_video_resolution_%240p_Den],[YTB_video_resolution_360p_Num],[YTB_video_resolution_360p_Den]
    ,[YTB_video_mos_360p_Num],[YTB_video_mos_360p_Den],[YTB_video_resolution_%360p_Num],[YTB_video_resolution_%360p_Den],[YTB_video_resolution_480p_Num]
    ,[YTB_video_resolution_480p_Den],[YTB_video_mos_480p_Num],[YTB_video_mos_480p_Den],[YTB_video_resolution_%480p_Num]
    ,[YTB_video_resolution_%480p_Den],[YTB_video_resolution_720p_Num],[YTB_video_resolution_720p_Den],[YTB_video_mos_720p_Num]
    ,[YTB_video_mos_720p_Den],[YTB_video_resolution_%720p_Num],[YTB_video_resolution_%720p_Den],[YTB_video_resolution_1080p_Num]
    ,[YTB_video_resolution_1080p_Den],[YTB_video_mos_1080p_Num],[YTB_video_mos_1080p_Den],[YTB_video_resolution_%1080p_Num]
    ,[YTB_video_resolution_%1080p_Den],[Avg_Video_StarTime_Num_Video1],[Avg_Video_startTime_Den_Video1],[Reproductions_WO_Interruptions_Video1]
    ,[Reproductions_WO_Interruptions_Den_Video1],[HD_reproduction_rate_num_Video1],[HD_reproduction_rate_den_Video1]
    ,[YTB_video_resolution_num_Video1],[YTB_video_resolution_den_Video1],[YTB_video_mos_num_Video1],[YTB_video_mos_den_Video1],[YTB_url_Video1]
    ,[B4_Video1],[ReproduccionesHD_Video1],[Successful video download_Video1],[Reproducciones_Video1],[YTB_1st_Resolution_Num_Video1]
    ,[YTB_1st_Resolution_Den_Video1],[YTB_2nd_Resolution_Num_Video1],[YTB_2nd_Resolution_Den_Video1],[YTB_FirstChangeFromInit_Num_Video1]
    ,[YTB_FirstChangeFromInit_Den_Video1],[YTB_initialResolution_Num_Video1],[YTB_initialResolution_Den_Video1]
    ,[YTB_finalResolution_Num_Video1],[YTB_finalResolution_Den_Video1],[YTB_video_resolution_144p_Num_Video1]
    ,[YTB_video_resolution_144p_Den_Video1],[YTB_video_mos_144p_Num_Video1],[YTB_video_mos_144p_Den_Video1],[YTB_video_resolution_%144p_Num_Video1]
    ,[YTB_video_resolution_%144p_Den_Video1],[YTB_video_resolution_240p_Num_Video1],[YTB_video_resolution_240p_Den_Video1]
    ,[YTB_video_mos_240p_Num_Video1],[YTB_video_mos_240p_Den_Video1],[YTB_video_resolution_%240p_Num_Video1],[YTB_video_resolution_%240p_Den_Video1]
    ,[YTB_video_resolution_360p_Num_Video1],[YTB_video_resolution_360p_Den_Video1],[YTB_video_mos_360p_Num_Video1]
    ,[YTB_video_mos_360p_Den_Video1],[YTB_video_resolution_%360p_Num_Video1],[YTB_video_resolution_%360p_Den_Video1],[YTB_video_resolution_480p_Num_Video1]
    ,[YTB_video_resolution_480p_Den_Video1],[YTB_video_mos_480p_Num_Video1],[YTB_video_mos_480p_Den_Video1],[YTB_video_resolution_%480p_Num_Video1]
    ,[YTB_video_resolution_%480p_Den_Video1],[YTB_video_resolution_720p_Num_Video1],[YTB_video_resolution_720p_Den_Video1],[YTB_video_mos_720p_Num_Video1]
    ,[YTB_video_mos_720p_Den_Video1],[YTB_video_resolution_%720p_Num_Video1],[YTB_video_resolution_%720p_Den_Video1]
    ,[YTB_video_resolution_1080p_Num_Video1],[YTB_video_resolution_1080p_Den_Video1],[YTB_video_mos_1080p_Num_Video1],[YTB_video_mos_1080p_Den_Video1]
    ,[YTB_video_resolution_%1080p_Num_Video1],[YTB_video_resolution_%1080p_Den_Video1],[Avg_Video_StarTime_Num_Video2],[Avg_Video_startTime_Den_Video2]
    ,[Reproductions_WO_Interruptions_Video2],[Reproductions_WO_Interruptions_Den_Video2],[HD_reproduction_rate_num_Video2]
    ,[HD_reproduction_rate_den_Video2],[YTB_video_resolution_num_Video2],[YTB_video_resolution_den_Video2],[YTB_video_mos_num_Video2]
    ,[YTB_video_mos_den_Video2],[YTB_url_Video2],[B4_Video2],[ReproduccionesHD_Video2],[Successful video download_Video2]
    ,[Reproducciones_Video2],[YTB_1st_Resolution_Num_Video2],[YTB_1st_Resolution_Den_Video2],[YTB_2nd_Resolution_Num_Video2]
    ,[YTB_2nd_Resolution_Den_Video2],[YTB_FirstChangeFromInit_Num_Video2],[YTB_FirstChangeFromInit_Den_Video2],[YTB_initialResolution_Num_Video2]
    ,[YTB_initialResolution_Den_Video2],[YTB_finalResolution_Num_Video2],[YTB_finalResolution_Den_Video2]
    ,[YTB_video_resolution_144p_Num_Video2],[YTB_video_resolution_144p_Den_Video2],[YTB_video_mos_144p_Num_Video2],[YTB_video_mos_144p_Den_Video2]
    ,[YTB_video_resolution_%144p_Num_Video2],[YTB_video_resolution_%144p_Den_Video2],[YTB_video_resolution_240p_Num_Video2]
    ,[YTB_video_resolution_240p_Den_Video2],[YTB_video_mos_240p_Num_Video2],[YTB_video_mos_240p_Den_Video2]
    ,[YTB_video_resolution_%240p_Num_Video2],[YTB_video_resolution_%240p_Den_Video2],[YTB_video_resolution_360p_Num_Video2]
    ,[YTB_video_resolution_360p_Den_Video2],[YTB_video_mos_360p_Num_Video2],[YTB_video_mos_360p_Den_Video2],[YTB_video_resolution_%360p_Num_Video2]
    ,[YTB_video_resolution_%360p_Den_Video2],[YTB_video_resolution_480p_Num_Video2],[YTB_video_resolution_480p_Den_Video2],[YTB_video_mos_480p_Num_Video2]
    ,[YTB_video_mos_480p_Den_Video2],[YTB_video_resolution_%480p_Num_Video2],[YTB_video_resolution_%480p_Den_Video2],[YTB_video_resolution_720p_Num_Video2]
    ,[YTB_video_resolution_720p_Den_Video2],[YTB_video_mos_720p_Num_Video2],[YTB_video_mos_720p_Den_Video2],[YTB_video_resolution_%720p_Num_Video2]
    ,[YTB_video_resolution_%720p_Den_Video2],[YTB_video_resolution_1080p_Num_Video2],[YTB_video_resolution_1080p_Den_Video2]
    ,[YTB_video_mos_1080p_Num_Video2],[YTB_video_mos_1080p_Den_Video2],[YTB_video_resolution_%1080p_Num_Video2]
    ,[YTB_video_resolution_%1080p_Den_Video2],[Avg_Video_StarTime_Num_Video3],[Avg_Video_startTime_Den_Video3]
    ,[Reproductions_WO_Interruptions_Video3],[Reproductions_WO_Interruptions_Den_Video3],[HD_reproduction_rate_num_Video3]
    ,[HD_reproduction_rate_den_Video3],[YTB_video_resolution_num_Video3],[YTB_video_resolution_den_Video3]
    ,[YTB_video_mos_num_Video3],[YTB_video_mos_den_Video3],[YTB_url_Video3],[B4_Video3],[ReproduccionesHD_Video3],[Successful video download_Video3],[Reproducciones_Video3]
    ,[YTB_1st_Resolution_Num_Video3],[YTB_1st_Resolution_Den_Video3],[YTB_2nd_Resolution_Num_Video3],[YTB_2nd_Resolution_Den_Video3]
    ,[YTB_FirstChangeFromInit_Num_Video3],[YTB_FirstChangeFromInit_Den_Video3],[YTB_initialResolution_Num_Video3]
    ,[YTB_initialResolution_Den_Video3],[YTB_finalResolution_Num_Video3],[YTB_finalResolution_Den_Video3]
    ,[YTB_video_resolution_144p_Num_Video3],[YTB_video_resolution_144p_Den_Video3],[YTB_video_mos_144p_Num_Video3],[YTB_video_mos_144p_Den_Video3]
    ,[YTB_video_resolution_%144p_Num_Video3],[YTB_video_resolution_%144p_Den_Video3],[YTB_video_resolution_240p_Num_Video3],[YTB_video_resolution_240p_Den_Video3]
    ,[YTB_video_mos_240p_Num_Video3],[YTB_video_mos_240p_Den_Video3],[YTB_video_resolution_%240p_Num_Video3],[YTB_video_resolution_%240p_Den_Video3]
    ,[YTB_video_resolution_360p_Num_Video3],[YTB_video_resolution_360p_Den_Video3],[YTB_video_mos_360p_Num_Video3],[YTB_video_mos_360p_Den_Video3]
    ,[YTB_video_resolution_%360p_Num_Video3],[YTB_video_resolution_%360p_Den_Video3],[YTB_video_resolution_480p_Num_Video3],[YTB_video_resolution_480p_Den_Video3]
    ,[YTB_video_mos_480p_Num_Video3],[YTB_video_mos_480p_Den_Video3],[YTB_video_resolution_%480p_Num_Video3],[YTB_video_resolution_%480p_Den_Video3]
    ,[YTB_video_resolution_720p_Num_Video3],[YTB_video_resolution_720p_Den_Video3],[YTB_video_mos_720p_Num_Video3],[YTB_video_mos_720p_Den_Video3]
    ,[YTB_video_resolution_%720p_Num_Video3],[YTB_video_resolution_%720p_Den_Video3],[YTB_video_resolution_1080p_Num_Video3]
    ,[YTB_video_resolution_1080p_Den_Video3],[YTB_video_mos_1080p_Num_Video3]
    ,[YTB_video_mos_1080p_Den_Video3],[YTB_video_resolution_%1080p_Num_Video3],[YTB_video_resolution_%1080p_Den_Video3],[Avg_Video_StarTime_Num_Video4]
    ,[Avg_Video_startTime_Den_Video4],[Reproductions_WO_Interruptions_Video4],[Reproductions_WO_Interruptions_Den_Video4],[HD_reproduction_rate_num_Video4],[HD_reproduction_rate_den_Video4]
    ,[YTB_video_resolution_num_Video4],[YTB_video_resolution_den_Video4],[YTB_video_mos_num_Video4],[YTB_video_mos_den_Video4]
    ,[YTB_url_Video4],[B4_Video4],[ReproduccionesHD_Video4],[Successful video download_Video4],[Reproducciones_Video4],[YTB_1st_Resolution_Num_Video4]
    ,[YTB_1st_Resolution_Den_Video4],[YTB_2nd_Resolution_Num_Video4],[YTB_2nd_Resolution_Den_Video4],[YTB_FirstChangeFromInit_Num_Video4]
    ,[YTB_FirstChangeFromInit_Den_Video4],[YTB_initialResolution_Num_Video4],[YTB_initialResolution_Den_Video4],[YTB_finalResolution_Num_Video4]
    ,[YTB_finalResolution_Den_Video4],[YTB_video_resolution_144p_Num_Video4],[YTB_video_resolution_144p_Den_Video4],[YTB_video_mos_144p_Num_Video4]
    ,[YTB_video_mos_144p_Den_Video4],[YTB_video_resolution_%144p_Num_Video4],[YTB_video_resolution_%144p_Den_Video4],[YTB_video_resolution_240p_Num_Video4]
    ,[YTB_video_resolution_240p_Den_Video4],[YTB_video_mos_240p_Num_Video4],[YTB_video_mos_240p_Den_Video4],[YTB_video_resolution_%240p_Num_Video4]
	,[YTB_video_resolution_%240p_Den_Video4],[YTB_video_resolution_360p_Num_Video4],[YTB_video_resolution_360p_Den_Video4]
    ,[YTB_video_mos_360p_Num_Video4],[YTB_video_mos_360p_Den_Video4],[YTB_video_resolution_%360p_Num_Video4]
    ,[YTB_video_resolution_%360p_Den_Video4],[YTB_video_resolution_480p_Num_Video4],[YTB_video_resolution_480p_Den_Video4]
    ,[YTB_video_mos_480p_Num_Video4],[YTB_video_mos_480p_Den_Video4],[YTB_video_resolution_%480p_Num_Video4],[YTB_video_resolution_%480p_Den_Video4]
    ,[YTB_video_resolution_720p_Num_Video4],[YTB_video_resolution_720p_Den_Video4],[YTB_video_mos_720p_Num_Video4],[YTB_video_mos_720p_Den_Video4]
    ,[YTB_video_resolution_%720p_Num_Video4],[YTB_video_resolution_%720p_Den_Video4],[YTB_video_resolution_1080p_Num_Video4]
    ,[YTB_video_resolution_1080p_Den_Video4],[YTB_video_mos_1080p_Num_Video4],[YTB_video_mos_1080p_Den_Video4],[YTB_video_resolution_%1080p_Num_Video4]
    ,[YTB_video_resolution_%1080p_Den_Video4],[Region_Road_VF],[Region_Road_OSP],[Region_VF],[Region_OSP]
    ,[ASideDevice],[BSideDevice],[SWVersion],[YTB_Version],[Provincia],[CCAA],[rango_pobl],[resp_sharing],[completed],[Provincia_comp]
    ,[scope],[last_measurement_vdf],[last_measurement_osp],[last_measurement_osp_noComp],[meas_LA]

into _replicas_review'+@version+'

from _min_round_null_review'+@version+' mrn

	left join (Select l.* from '+@BBDD+'.dbo.'+@tablename+' l where l.environment = '''+@environment+''' and l.meas_tech like '''+@meas_tech+''') l

on (mrn.entity=l.entity and mrn.test_type=l.test_type and mrn.report_type=l.report_type and mrn.operator=l.operator and mrn.meas_tech = l.meas_tech and mrn.meas_min=l.'+@last_measurement+')


where (mrn.meas_min <> '+@RollWindow+' and last_measurement_vdf <> '+@RollWindow+')
	 

--Select * from _replicas_review'+@version+'


--****************************************************************************
--	Añadimos a la tabla original las réplicas -----
--****************************************************************************

--	drop table _Completed_review'+@version+'

Select *

into _Completed_review'+@version+'

from '+@BBDD+'.dbo.'+@tablename+'

union all

Select *

from _replicas_review'+@version+'

--Select * from _Completed_review'+@version+' where environment like ''%AVE%''


--****************************************************************************
--	Recalculamos los last_measurement de los AVES ------
--****************************************************************************



Update _Completed_review'+@version+'
set '+@last_measurement+' = Case when l.meas_order = 1 and '+@id+' = 1 then 1 else
								 Case when (l.meas_order <= '+@RollWindow+' and '+@id+' = 1 and c.environment like '''+@environment+''' and c.meas_tech like '''+@meas_tech+''') then l.meas_order
								      else 0 end
							end
					
from _Completed_review'+@version+' c,

		--(Select entity,mnc, meas_tech,meas_date,meas_week,test_type,report_type,round,
		--		row_number() over (partition by entity,mnc, meas_tech, test_type,report_type
		--		order by meas_date DESC,cast(replace(meas_Week,''W'','''') as int) desc) meas_order
		--from _Completed_review'+@version+'
		--where environment in (''AVE'',''Roads'') and scope in (''RAILWAYS'',''MAIN HIGHWAYS'')
		--group by entity,mnc, meas_tech,meas_date,meas_week,report_type,test_type,round) l

		( 
		select entity, mnc, meas_tech, meas_round, meas_date, meas_week, test_type, report_type, round,
				row_number() over 
					(partition by entity, mnc, meas_tech, test_type, report_type
						order by case when max('+@id+') = 1 then max('+@id+') end DESC, meas_round DESC, case when report_type = '''+@report+''' then report_type end DESC,
							meas_date DESC, cast(replace(meas_Week,''W'','''') as int) desc
					) meas_order
		from _Completed_review'+@version+'
		where environment in (''AVE'',''Roads'') and scope in (''RAILWAYS'',''MAIN HIGHWAYS'')  
		group by entity, mnc, meas_tech, meas_round, meas_date, meas_Week, report_type, test_type,round			
		) l	--new

where 
	c.entity=l.entity and 
	c.mnc=l.mnc and 
	c.meas_tech=l.meas_tech and 
	c.meas_round = l.meas_round and		-- new l
	c.meas_week=l.meas_week and 
	c.test_type=l.test_type and 
	c.report_type=l.report_type and 
	c.round=l.round and 
	c.environment = '''+@environment+''' and 
	c.meas_tech like '''+@meas_tech+'''

--	Select * from _Completed_review'+@version+' where environment like ''%AVE%''

')
------------------------- COMPROBACIÓN FINAL ----------------------------

--Select *
--from _Completed_review'+@version+'
--where environment = 'AVE'

END

ELSE

BEGIN

exec('

--****************************************************************************
--	1. Sacamos los nulos, que serán las medidas que haya que rellenar---------
--****************************************************************************

select a.entity,a.report_type,a.round,a.operator,b.environment,a.meas_tech,a.meas_date,a.meas_week,a.'+@last_measurement+'

into _null_review'+@version+'

from
(Select a.*, b.operator

from (
Select distinct(entity),report_type,round,'+@last_measurement+',meas_tech,meas_date,meas_week
from '+@BBDD+'.dbo.'+@tablename+'  
where '+@last_measurement+' <> 0 and operator = ''Vodafone'' and environment = '''+@environment+'''and meas_tech like '''+@meas_tech+''')a,

(select operator from '+@BBDD+'.dbo.'+@tablename+' group by operator) b


) a

left outer join 

( Select * from '+@BBDD+'.dbo.'+@tablename+' b where b.'+@last_measurement+' <> 0 and b.environment = '''+@environment+'''and meas_tech like '''+@meas_tech+''') b

 on (a.entity=b.entity and a.operator=b.operator and a.report_type=b.report_type and a.round=b.round
     and a.meas_tech = b.meas_tech and a.meas_date=b.meas_date and a.meas_week=b.meas_week)
 where environment is null 
 

--****************************************************************************
--	2. Detectamos la vuelta más reciente a rellenar si hubiese más de una
--****************************************************************************

Select n.entity,n.report_type,n.round,n.operator,n.meas_tech,n.meas_date,n.meas_week,m.meas_min

into _min_round_null_review'+@version+'

from _null_review'+@version+' n

left join

 (Select entity,report_type, operator,meas_tech,min('+@last_measurement+') as meas_min from _null_review'+@version+' group by entity, report_type,operator,meas_tech) m

on (n.entity=m.entity and n.report_type=m.report_type and n.operator=m.operator
    and n.'+@last_measurement+' = m.meas_min and n.meas_tech=m.meas_tech)

 where m.meas_min is not null



--****************************************************************************
--	3. Detectamos la última vuelta válida para cada una de las entidades con NULOS---------
--****************************************************************************
Select 
	l.[codigo_ine],l.[environment],l.[operator],l.[mnc],l.[meas_round],l.[meas_date],l.[meas_week],l.[meas_Tech],
	l.[Report_Type],l.[id_vdf],l.[id_osp],l.[id_osp_noComp],l.[entity],l.[Round],l.[Poblacion],l.[calltype]

	,[MOC_Calls]	,[MTC_Calls]	,[MOC_Blocks]	,[MTC_Blocks]	,[MOC_Drops]	,[MTC_Drops]	,[Calls]	,[Blocks]	,[Drops],	[CR_Affected_Calls]	 /*,[Calls_Started_2G]	,[Calls_Started_3G]	,[Calls_Started_4G]*/	,[Call_duration_3G]	,[Call_duration_2G]	,[Call_duration_tech_samples]
	,[CSFB_to_GSM_samples]	,[CSFB_to_UMTS_samples]	,[CSFB_samples]	,[NUMBERS OF CALLS Non Sustainability (NB)]	,[NUMBERS OF CALLS Non Sustainability (WB)]	,[Calls_Started_2G_WO_Fails]	,[Calls_Started_3G_WO_Fails]	,[Calls_Started_4G_WO_Fails]	,[Calls_Mixed]	,[VOLTE_SpeechDelay_Num]
	,[VOLTE_SpeechDelay_Den]	,[VOLTE_Calls_Started_Ended_VOLTE]	,[VOLTE_Calls_withSRVCC]	,[VOLTE_Calls_is_VOLTE]	,[MOS_Num]	,[MOS_Samples]	,[AMR_FR_samples]	,[AMR_HR_samples]	,[AMR_WB_samples]	,[FR_samples]	,[EFR_samples]	,[HR_samples]	,[codec_samples]
	,[1_WB]	,[2_WB]	,[3_WB]	,[4_WB]	,[5_WB]	,[6_WB]	,[7_WB]	,[8_WB]	,[MOS Below 2.5 Samples WB]	,[MOS Over 3.5 Samples WB]	,[MOS ALL Samples WB]	,[1_NB]	,[2_NB]	,[3_NB]	,[4_NB]	,[5_NB]	,[6_NB]	,[7_NB]	,[8_NB]
	,[MOS Below 2.5 Samples NB]	,[MOS Over 3.5 Samples NB]	,[MOS ALL Samples NB]	,[MOS_Samples_Under_2.5]	,[MOS_NB_Samples_Under_2.5]	,[Samples_DL+UL]	,[Samples_DL+UL_NB]	,[WB AMR Only]	,[Avg WB AMR Only]	,[MOS_NB_Num]	,[MOS_NB_Den]	,[WB_AMR_Only_Num]	,[WB_AMR_Only_Den]	,[MOS_Overall_Samples_Under_2.5]
	,[CST_ALERTING_NUM]	,[CST_CONNECT_NUM]	,[CST_MO_AL_samples]	,[CST_MT_AL_samples]	,[CST_MO_CO_samples]	,[CST_MT_CO_samples]	,[CST_MO_AL_NUM]	,[CST_MT_AL_NUM]	,[CST_MO_CO_NUM]	,[CST_MT_CO_NUM]	,[CST_ALERTING_UMTS_samples]	,[CST_ALERTING_UMTS900_samples]
	,[CST_ALERTING_UMTS2100_samples]	,[CST_ALERTING_GSM_samples]	,[CST_ALERTING_GSM900_samples]	,[CST_ALERTING_GSM1800_samples]	,[CST_ALERTING_UMTS_NUM]	,[CST_ALERTING_UMTS900_NUM]	,[CST_ALERTING_UMTS2100_NUM]	,[CST_ALERTING_GSM_NUM]	,[CST_ALERTING_GSM900_NUM]
	,[CST_ALERTING_GSM1800_NUM]	,[CST_CONNECT_UMTS_samples]	,[CST_CONNECT_UMTS900_samples]	,[CST_CONNECT_UMTS2100_samples]	,[CST_CONNECT_GSM_samples]	,[CST_CONNECT_GSM900_samples]	,[CST_CONNECT_GSM1800_samples]	,[CST_CONNECT_UMTS_NUM]	,[CST_CONNECT_UMTS900_NUM]
	,[CST_CONNECT_UMTS2100_NUM]	,[CST_CONNECT_GSM_NUM]	,[CST_CONNECT_GSM900_NUM]	,[CST_CONNECT_GSM1800_NUM]	,[CSFB_duration_samples]	,[CSFB_duration_num]
	,[1_MO_A]	,[2_MO_A]	,[3_MO_A]	,[4_MO_A]	,[5_MO_A]	,[6_MO_A]	,[7_MO_A]	,[8_MO_A]	,[9_MO_A]	,[10_MO_A]	,[11_MO_A]	,[12_MO_A]	,[13_MO_A]	,[14_MO_A]	,[15_MO_A]	,[16_MO_A]	,[17_MO_A]	,[18_MO_A]	,[19_MO_A]	,[20_MO_A]
	,[21_MO_A]	,[22_MO_A]	,[23_MO_A]	,[24_MO_A]	,[25_MO_A]	,[26_MO_A]	,[27_MO_A]	,[28_MO_A]	,[29_MO_A]	,[30_MO_A]	,[31_MO_A]	,[32_MO_A]	,[33_MO_A]	,[34_MO_A]	,[35_MO_A]	,[36_MO_A]	,[37_MO_A]	,[38_MO_A]	,[39_MO_A]	,[40_MO_A]	,[41_MO_A]
	,[1_MT_A]	,[2_MT_A]	,[3_MT_A]	,[4_MT_A]	,[5_MT_A]	,[6_MT_A]	,[7_MT_A]	,[8_MT_A]	,[9_MT_A]	,[10_MT_A]	,[11_MT_A]	,[12_MT_A]	,[13_MT_A]	,[14_MT_A]	,[15_MT_A]	,[16_MT_A]	,[17_MT_A]	,[18_MT_A]	,[19_MT_A]	,[20_MT_A]
	,[21_MT_A]	,[22_MT_A]	,[23_MT_A]	,[24_MT_A]	,[25_MT_A]	,[26_MT_A]	,[27_MT_A]	,[28_MT_A]	,[29_MT_A]	,[30_MT_A]	,[31_MT_A]	,[32_MT_A]	,[33_MT_A]	,[34_MT_A]	,[35_MT_A]	,[36_MT_A]	,[37_MT_A]	,[38_MT_A]	,[39_MT_A]	,[40_MT_A]	,[41_MT_A]
	,[1_MOMT_A]	,[2_MOMT_A]	,[3_MOMT_A]	,[4_MOMT_A]	,[5_MOMT_A]	,[6_MOMT_A]	,[7_MOMT_A]	,[8_MOMT_A]	,[9_MOMT_A]	,[10_MOMT_A]	,[11_MOMT_A]	,[12_MOMT_A]	,[13_MOMT_A]	,[14_MOMT_A]	,[15_MOMT_A]	,[16_MOMT_A]	,[17_MOMT_A]	,[18_MOMT_A]	,[19_MOMT_A]	,[20_MOMT_A]
	,[21_MOMT_A]	,[22_MOMT_A]	,[23_MOMT_A]	,[24_MOMT_A]	,[25_MOMT_A]	,[26_MOMT_A]	,[27_MOMT_A]	,[28_MOMT_A]	,[29_MOMT_A]	,[30_MOMT_A]	,[31_MOMT_A]	,[32_MOMT_A]	,[33_MOMT_A]	,[34_MOMT_A]	,[35_MOMT_A]	,[36_MOMT_A]	,[37_MOMT_A]	,[38_MOMT_A]	,[39_MOMT_A]	,[40_MOMT_A]	,[41_MOMT_A]
	,[1_MO_C]	,[2_MO_C]	,[3_MO_C]	,[4_MO_C]	,[5_MO_C]	,[6_MO_C]	,[7_MO_C]	,[8_MO_C]	,[9_MO_C]	,[10_MO_C]	,[11_MO_C]	,[12_MO_C]	,[13_MO_C]	,[14_MO_C]	,[15_MO_C]	,[16_MO_C]	,[17_MO_C]	,[18_MO_C]	,[19_MO_C]	,[20_MO_C]
	,[21_MO_C]	,[22_MO_C]	,[23_MO_C]	,[24_MO_C]	,[25_MO_C]	,[26_MO_C]	,[27_MO_C]	,[28_MO_C]	,[29_MO_C]	,[30_MO_C]	,[31_MO_C]	,[32_MO_C]	,[33_MO_C]	,[34_MO_C]	,[35_MO_C]	,[36_MO_C]	,[37_MO_C]	,[38_MO_C]	,[39_MO_C]	,[40_MO_C]	,[41_MO_C]
	,[1_MT_C]	,[2_MT_C]	,[3_MT_C]	,[4_MT_C]	,[5_MT_C]	,[6_MT_C]	,[7_MT_C]	,[8_MT_C]	,[9_MT_C]	,[10_MT_C]	,[11_MT_C]	,[12_MT_C]	,[13_MT_C]	,[14_MT_C]	,[15_MT_C]	,[16_MT_C]	,[17_MT_C]	,[18_MT_C]	,[19_MT_C]	,[20_MT_C]
	,[21_MT_C]	,[22_MT_C]	,[23_MT_C]	,[24_MT_C]	,[25_MT_C]	,[26_MT_C]	,[27_MT_C]	,[28_MT_C]	,[29_MT_C]	,[30_MT_C]	,[31_MT_C]	,[32_MT_C]	,[33_MT_C]	,[34_MT_C]	,[35_MT_C]	,[36_MT_C]	,[37_MT_C]	,[38_MT_C]	,[39_MT_C]	,[40_MT_C]	,[41_MT_C]
	,[1_MOMT_C]	,[2_MOMT_C]	,[3_MOMT_C]	,[4_MOMT_C]	,[5_MOMT_C]	,[6_MOMT_C]	,[7_MOMT_C]	,[8_MOMT_C]	,[9_MOMT_C]	,[10_MOMT_C]	,[11_MOMT_C]	,[12_MOMT_C]	,[13_MOMT_C]	,[14_MOMT_C]	,[15_MOMT_C]	,[16_MOMT_C]	,[17_MOMT_C]	,[18_MOMT_C]	,[19_MOMT_C]	,[20_MOMT_C]
	,[21_MOMT_C]	,[22_MOMT_C]	,[23_MOMT_C]	,[24_MOMT_C]	,[25_MOMT_C]	,[26_MOMT_C]	,[27_MOMT_C]	,[28_MOMT_C]	,[29_MOMT_C]	,[30_MOMT_C]	,[31_MOMT_C]	,[32_MOMT_C]	,[33_MOMT_C]	,[34_MOMT_C]	,[35_MOMT_C]	,[36_MOMT_C]	,[37_MOMT_C]	,[38_MOMT_C]	,[39_MOMT_C]	,[40_MOMT_C]	,[41_MOMT_C]
	,[MOS_2G_Num]	,[MOS_2G_Samples]	,[MOS_3G_Num]	,[MOS_3G_Samples]	,[MOS_GSM_Num]	,[MOS_GSM_Samples]	,[MOS_DCS_Num]	,[MOS_DCS_Samples]	,[MOS_UMTS900_Num]	,[MOS_UMTS900_Samples]	,[MOS_UMTS2100_Num]	,[MOS_UMTS2100_Samples]	,[Call_duration_UMTS2100]
	,[Call_duration_UMTS900]	,[Call_duration_GSM]	,[Call_duration_DCS]	,[coverage4G_den]	,[coverage4G_den_ProbCob]	,[samples_4Gcov_num]	,[samples_L800cov_num]	,[samples_L1800cov_num]	,[samples_L2100cov_num]	,[samples_L2600cov_num]	,[samples_L800L1800cov_num]	,[samples_L800L2100cov_num]	,[samples_L800L2600cov_num]
	,[samples_L1800L2100cov_num]	,[samples_L1800L2600cov_num]	,[samples_L2100L2600cov_num]	,[samples_L800L1800L2100cov_num]	,[samples_L800L1800L2600cov_num]	,[samples_L1800L2100L2600cov_num]	,[samples_L800L1800L2100L2600cov_num]	,[samples_L800L2100L2600cov_num]	,[samples_L2100_BW5cov_num]
	,[samples_L2100_BW10cov_num]	,[samples_L2100_BW15cov_num]	,[samples_L1800_BW10cov_num]	,[samples_L1800_BW15cov_num]	,[samples_L1800_BW20cov_num]	,[cobertura_AVG_4G_Num]	,[cobertura_AVG_L800_Num]	,[cobertura_AVG_L1800_Num]	,[cobertura_AVG_L2100_Num]	,[cobertura_AVG_L2600_Num]	,[samplesAVG_4G]
	,[samplesAVG_L800]	,[samplesAVG_L1800]	,[samplesAVG_L2100]	,[samplesAVG_L2600]	,[LTE_ProbCobInd]	,[LTE2600_ProbCobInd]	,[LTE2100_ProbCobInd]	,[LTE2100_BW5_ProbCobInd]	,[LTE2100_BW10_ProbCobInd]	,[LTE2100_BW15_ProbCobInd]	,[LTE1800_ProbCobInd]	,[LTE1800_BW10_ProbCobInd]
	,[LTE1800_BW15_ProbCobInd]	,[LTE1800_BW20_ProbCobInd]	,[LTE800_ProbCobInd]	,[LTE800_1800_ProbCobInd]	,[LTE800_2100_ProbCobInd]	,[LTE800_2600_ProbCobInd]	,[LTE1800_2100_ProbCobInd]	,[LTE1800_2600_ProbCobInd]	,[LTE2100_2600_ProbCobInd]	,[LTE800_1800_2100_ProbCobInd]	,[LTE800_1800_2600_ProbCobInd]
	,[LTE800_2100_2600_ProbCobInd]	,[LTE1800_2100_2600_ProbCobInd]	,[LTE_Samples_ProbCobInd]	,[LTE2600_Samples_ProbCobInd]	,[LTE2100_Samples_ProbCobInd]	,[LTE2100_BW5_Samples_ProbCobInd]	,[LTE2100_BW10_Samples_ProbCobInd]	,[LTE2100_BW15_Samples_ProbCobInd]	,[LTE1800_Samples_ProbCobInd]	,[LTE1800_BW10_Samples_ProbCobInd]
	,[LTE1800_BW15_Samples_ProbCobInd]	,[LTE1800_BW20_Samples_ProbCobInd]	,[LTE800_Samples_ProbCobInd]	,[LTE800_1800_Samples_ProbCobInd]	,[LTE800_2100_Samples_ProbCobInd]	,[LTE800_2600_Samples_ProbCobInd]	,[LTE1800_2100_Samples_ProbCobInd]	,[LTE1800_2600_Samples_ProbCobInd]	,[LTE2100_2600_Samples_ProbCobInd]	,[LTE800_1800_2100_Samples_ProbCobInd]
	,[LTE800_1800_2600_Samples_ProbCobInd]	,[LTE800_2100_2600_Samples_ProbCobInd]	,[LTE1800_2100_2600_Samples_ProbCobInd]	,[coverage3G_den]	,[coverage3G_den_ProbCob]	,[samples_3Gcov_num]	,[samples_U2100cov_num]	,[samples_UMTS900cov_num]	,[samples_U900U2100cov_num]	,[samples_U2100_2Carriers_cov_num]	,[samples_U900U2100_2Carriers_cov_num]
	,[samples_U2100_3Carriers_cov_num]	,[samples_U900U2100_3Carriers_cov_num]	,[samples_U2100_1Carriers_cov_num]	,[UMTS2100_F1]
	,[UMTS2100_F2]	,[UMTS2100_F3],[UMTS2100_P1],[UMTS2100_P2]	,[UMTS2100_P3], [UMTS900_F1],[UMTS900_F2], [UMTS900_P1],[UMTS900_P2],[UMTS2100_F1_F2]	,[UMTS2100_F1_F3]	,[UMTS2100_F2_F3]	,[UMTS900_U2100_F1]	,[UMTS900_U2100_F2]	,[UMTS900_U2100_F3]	,[UMTS900_U2100_F1_F2]	,[UMTS900_U2100_F1_F3]	,[UMTS900_U2100_F2_F3]	,[cobertura_AVG_3G_Num]	,[cobertura_AVG_U2100_Num]	,[cobertura_AVG_U900_Num]	,[samplesAVG_3G]
	,[samplesAVG_U2100]	,[samplesAVG_U900]	,[Pollution]	,[Pollution BS Curves]	,[Pollution BS Curves UMTS2100]	,[Pollution BS Curves UMTS900]	,[Pollution BS RSCP]	,[Pollution BS RSCP UMTS2100]	,[Pollution BS RSCP UMTS900]	,[UMTS_ProbCobInd]	,[UMTS2100_ProbCobInd]	,[UMTS2100_F1_ProbCobInd]
	,[UMTS2100_F2_ProbCobInd]	,[UMTS2100_F3_ProbCobInd],[UMTS2100_P1_ProbCobInd],[UMTS2100_P2_ProbCobInd]	,[UMTS2100_P3_ProbCobInd]	,[UMTS2100_F1_F2_ProbCobInd]	,[UMTS2100_F1_F3_ProbCobInd]	,[UMTS2100_F2_F3_ProbCobInd]	,[UMTS2100_F1_F2_F3_ProbCobInd]	,[UMTS900_ProbCobInd],[UMTS900_F1_ProbCobInd],[UMTS900_F2_ProbCobInd] ,[UMTS900_P1_ProbCobInd],[UMTS900_P2_ProbCobInd],[UMTS900_U2100_F1_ProbCobInd]	,[UMTS900_U2100_F2_ProbCobInd]	,[UMTS900_U2100_F3_ProbCobInd]	,[UMTS900_U2100_F1_F2_ProbCobInd]
	,[UMTS900_U2100_F1_F3_ProbCobInd]	,[UMTS900_U2100_F2_F3_ProbCobInd]	,[UMTS900_U2100_F1_F2_F3_ProbCobInd]	,[UMTS_Samples_ProbCobInd]	,[UMTS2100_Samples_ProbCobInd]	,[UMTS2100_F1_Samples_ProbCobInd]	,[UMTS2100_F2_Samples_ProbCobInd]	,[UMTS2100_F3_Samples_ProbCobInd] ,[UMTS2100_P1_Samples_ProbCobInd]	,[UMTS2100_P2_Samples_ProbCobInd]	,[UMTS2100_P3_Samples_ProbCobInd]	,[UMTS2100_F1_F2_Samples_ProbCobInd]	,[UMTS2100_F1_F3_Samples_ProbCobInd]
	,[UMTS2100_F2_F3_Samples_ProbCobInd]	,[UMTS2100_F1_F2_F3_Samples_ProbCobInd]	,[UMTS900_Samples_ProbCobInd],[UMTS900_F1_Samples_ProbCobInd],[UMTS900_F2_Samples_ProbCobInd],[UMTS900_P1_Samples_ProbCobInd],[UMTS900_P2_Samples_ProbCobInd]	,[UMTS900_U2100_F1_Samples_ProbCobInd]	,[UMTS900_U2100_F2_Samples_ProbCobInd]	,[UMTS900_U2100_F3_Samples_ProbCobInd]	,[UMTS900_U2100_F1_F2_Samples_ProbCobInd]	,[UMTS900_U2100_F1_F3_Samples_ProbCobInd]	,[UMTS900_U2100_F2_F3_Samples_ProbCobInd]
	,[UMTS900_U2100_F1_F2_F3_Samples_ProbCobInd]	,[UMTS2100_Carrier_only_ProbCobInd]	,[UMTS2100_Dual_Carrier_ProbCobInd]	,[UMTS900_U2100_Carrier_only_ProbCobInd]	,[UMTS900_U2100_Dual_Carrier_ProbCobInd]	,[UMTS2100_Carrier_only_Samples_ProbCobInd]	,[UMTS2100_Dual_Carrier_Samples_ProbCobInd]	,[UMTS900_U2100_Carrier_only_Samples_ProbCobInd]
	,[UMTS900_U2100_Dual_Carrier_Samples_ProbCobInd]	,[coverage2G_den]	, [coverage2G_den_ProbCob], [samples_2Gcov_num]	,[samples_GSMcov_num]	,[samples_DCScov_num]	,[samples_GSMDCScov_num]	,[cobertura_AVG_2G_Num]	,[cobertura_AVG_GSM_Num]	,[cobertura_AVG_DCS_Num]	,[samplesAVG_2G]	,[samplesAVG_GSM]	,[samplesAVG_DCS]
	,[2G_ProbCobInd]	,[GSM_ProbCobInd]	,[DCS_ProbCobInd]	,[GSM_DCS_ProbCobInd]	,[2G_Samples_ProbCobInd]	,[GSM_Samples_ProbCobInd]	,[DCS_Samples_ProbCobInd]	,[GSM_DCS_Samples_ProbCobInd]	,[LTE_ProbCobInd_Pob_Entidad]	,[UMTS_ProbCobInd_Pob_Entidad]	,[2G_ProbCobInd_Pob_Entidad]
	,[Region_Road_VF]	,[Region_Road_OSP]	,[Region_VF]	,[Region_OSP]	,[ASideDevice]      ,[BSideDevice]     ,[SWVersion],	[provincia]	,[CCAA]	,[rango_pobl]	,[resp_sharing]	,[completed]	,[provincia_comp]	,[scope]	,[last_measurement_vdf]	,[last_measurement_osp]	,[last_measurement_osp_noComp]	,[meas_LA]

into _replicas_review'+@version+'

from _min_round_null_review'+@version+' mrn

	left join (Select l.* from '+@BBDD+'.dbo.'+@tablename+' l where l.environment = '''+@environment+''' and l.meas_tech like '''+@meas_tech+''') l

on (mrn.entity=l.entity  and mrn.report_type=l.report_type and mrn.operator=l.operator and mrn.meas_tech = l.meas_tech and mrn.meas_min=l.'+@last_measurement+')

where (mrn.meas_min <> '+@RollWindow+' and last_measurement_vdf <> '+@RollWindow+')



--****************************************************************************
--	Añadimos a la tabla original las réplicas -----
--****************************************************************************
Select *

into _Completed_review'+@version+'

from '+@BBDD+'.dbo.'+@tablename+'

union all

Select *

from _replicas_review'+@version+'

--Select * from _Completed_review'+@version+' where environment like ''%AVE%''



--****************************************************************************
--	Recalculamos los last_measurement de los AVES ------
--****************************************************************************

Update _Completed_review'+@version+'
set '+@last_measurement+' = Case when l.meas_order = 1 and '+@id+' = 1 then 1 else
								 Case when (l.meas_order <= '+@RollWindow+' and '+@id+' = 1 and c.environment like '''+@environment+''' and c.meas_tech like '''+@meas_tech+''') then l.meas_order
								      else 0 end
							end

from _Completed_review'+@version+' c,

		--(
		--Select entity,mnc, meas_tech,meas_date,meas_week,report_type,round,
		--	row_number() over (partition by entity,mnc, meas_tech,report_type
		--	order by meas_date DESC,cast(replace(meas_Week,''W'','''') as int) desc) meas_order
		--from _Completed_review'+@version+'
		--where environment in (''AVE'',''Roads'') and scope in (''RAILWAYS'',''MAIN HIGHWAYS'')
		--group by entity,mnc, meas_tech,meas_date,meas_week,report_type,round
		--) l

		-- Se modifica el calculo en AVEs y ROADs:
		(
			select entity, mnc, meas_round, meas_tech, meas_date, meas_week, report_type, round,
					row_number() over 
					(partition by  entity, mnc, meas_tech
						order by case when max('+@id+') = 1 then max('+@id+') end DESC, meas_round DESC, case when report_type = '''+@report+''' then report_type end DESC,
							meas_date DESC, cast(replace(meas_Week,''W'','''') as int) DESC					 
						) as meas_order
			from _Completed_review'+@version+'
			where environment in (''AVE'',''Roads'') and scope in (''RAILWAYS'',''MAIN HIGHWAYS'')  
					and meas_tech not like ''%cover%''
			group by entity, mnc, meas_round, meas_tech, meas_date, meas_week, report_type, round

			--------
			union all		-- EXCEPCION de la cober de carreteras y aves, en las que para OSP, ya no se presenta VDF -> tienen umbrales diferentes
			select entity, mnc, meas_round, meas_tech, meas_date, meas_week, report_type, round,
					0 as meas_order
			from _Completed_review'+@version+'
			where environment in (''AVE'',''Roads'') and scope in (''RAILWAYS'',''MAIN HIGHWAYS'') and report_type='''+@reportVDF+'''
					and meas_tech like ''%cover%'' 
			group by entity, mnc, meas_round, meas_tech, meas_date, meas_week, report_type, round

			--------
			union all		-- EXCEPCION de la cober de carreteras y aves, en las que para OSP, ya no se presenta VDF -> tienen umbrales diferentes
			select entity, mnc, meas_round, meas_tech, meas_date, meas_week, report_type, round,
					row_number() over 
					(partition by  entity, mnc, meas_tech
						order by case when max('+@id+') = 1 then max('+@id+') end DESC, meas_round DESC, case when report_type = '''+@report+''' then report_type end DESC,
							meas_date DESC, cast(replace(meas_Week,''W'','''') as int) DESC					 
						) as meas_order
			from _Completed_review'+@version+'
			where environment in (''AVE'',''Roads'') and scope in (''RAILWAYS'',''MAIN HIGHWAYS'') and report_type<>'''+@reportVDF+'''
					and meas_tech like ''%cover%'' 
			group by entity, mnc, meas_round, meas_tech, meas_date, meas_week, report_type, round

		) l

where 
	c.entity=l.entity and 
	c.mnc=l.mnc and 
	c.meas_round = l.meas_round and
	c.meas_tech=l.meas_tech and 
	c.meas_week=l.meas_week and 
	c.report_type=l.report_type and 
	c.round=l.round and 
	c.environment = '''+@environment+''' and c.meas_tech like '''+@meas_tech+'''


')

END

--select * from _Completed_review'+@version+' where meas_tech like '%Road 4G%' and mnc = 04


-- Borramos todas las tablas intermedias
exec('exec QLIK.dbo.sp_lcc_dropifexists ''_null_review'+@version+'''')
exec('exec QLIK.dbo.sp_lcc_dropifexists ''_min_round_null_review'+@version+'''')
exec('exec QLIK.dbo.sp_lcc_dropifexists ''_replicas_review'+@version+'''')
--exec('exec QLIK.dbo.sp_lcc_dropifexists ''_Completed_review'+@version+'''')
