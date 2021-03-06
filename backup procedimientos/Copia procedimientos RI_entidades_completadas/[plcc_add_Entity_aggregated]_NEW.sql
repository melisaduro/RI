USE [AddedValue]
GO
/****** Object:  StoredProcedure [dbo].[plcc_add_Entity_aggregated]    Script Date: 11/07/2017 11:43:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [dbo].[plcc_add_Entity_aggregated]

as

--Variable declarations
declare @ddbbCoverage varchar(256)
declare @ddbbVoice3G varchar(256)
declare @ddbbData3G varchar(256)
declare @ddbbVoice4G varchar(256)
declare @ddbbVoiceVOLTE varchar(256)
declare @ddbbVoiceVOLTEROAD varchar(256)
declare @ddbbData4G varchar(256)
declare @ddbbVoiceROAD varchar(256)
declare @ddbbDataROAD varchar(256)
declare @ddbbCoverageROAD varchar(256)

declare @tableCoverageInd varchar(256)
declare @tableCoverageOut varchar(256)
declare @tableVoice varchar(256)
declare @tableData varchar(256)
declare @tableDataYTB varchar(256)
declare @tableData4GDevice varchar(256)


create table _temp_Entities
(
	entity_name varchar (255),
	meas_round varchar (50),
	is_Road nvarchar(1) 
)

set @ddbbCoverage = '[AGGRCoverage]'
set @ddbbCoverageROAD = '[AGGRCoverage_ROAD]'	
set @ddbbVoice3G = '[AggrVoice3G]'
set @ddbbVoice4G = '[AggrVoice4G]'
set @ddbbVoiceVOLTE = '[AggrVOLTE]'
set @ddbbVoiceVOLTEROAD = '[AggrVOLTE_ROAD]'
set @ddbbVoiceROAD = '[AggrVoice4G_ROAD]'
set @ddbbData3G = '[AggrData3G]'
set @ddbbData4G = '[AggrData4G]'
set @ddbbDataROAD = '[AggrData4G_ROAD]'	

set @tableCoverageInd = 'lcc_aggr_sp_MDD_Coverage_All_Indoor' --Entidades y roads (con su umbral inCar en el caso de OSP)
set @tableCoverageOut = 'lcc_aggr_sp_MDD_Coverage_All_Outdoor' --Aves
set @tableVoice = 'lcc_aggr_sp_MDD_Voice_Llamadas'
set @tableData = 'lcc_aggr_sp_MDD_Data_DL_Thput_CE'
set @tableDataYTB = 'lcc_aggr_sp_MDD_Data_Youtube_HD' --En datos comprobamos tb la tabla de YTB porque encontramos discrepancias de tener solo agregada esta info
set @tableData4GDevice = 'lcc_aggr_sp_MDD_Data_DL_Thput_CE_4GDevice'
	

--------------------------------------------------
--Insertamos nuevas entidades-rondas
--------------------------------------------------

--Insertamos todas las entidades-rondas existentes en el agregado
insert into _temp_Entities
exec ('
		select entidad,meas_round,''N''
			from '+@ddbbVoice3G+'.dbo.'+@tableVoice+' 
		group by entidad,meas_round
		union 
		select entidad,meas_round,''N''
			from '+@ddbbVoice4G+'.dbo.'+@tableVoice+' 
		group by entidad,meas_round
		union 
		select entidad,meas_round,''Y''
			from '+@ddbbVoiceROAD+'.dbo.'+@tableVoice+' 
		group by entidad,meas_round
		union 
		select entidad,meas_round,''N''
			from '+@ddbbVoiceVOLTE+'.dbo.'+@tableVoice+' 
		group by entidad,meas_round
--Descomentar cuando esté creada la bbdd VOLTE_ROAD
		--union 
		--select entidad,meas_round,''Y''
		--	from '+@ddbbVoiceVOLTEROAD+'.dbo.'+@tableVoice+' 
		--group by entidad,meas_round
		union 
		select entidad,meas_round,''N''
			from '+@ddbbData3G+'.dbo.'+@tableData+' 
		group by entidad,meas_round
		union 
		select entidad,meas_round,''N''
			from '+@ddbbData4G+'.dbo.'+@tableData+' 
		group by entidad,meas_round
		union 
		select entidad,meas_round,''Y''
			from '+@ddbbDataROAD+'.dbo.'+@tableData+' 
		group by entidad,meas_round
		union 
		select entidad,meas_round,''N''
			from '+@ddbbData4G+'.dbo.'+@tableDataYTB+' 
		group by entidad,meas_round
		union 
		select entidad,meas_round,''Y''
			from '+@ddbbDataROAD+'.dbo.'+@tableDataYTB+' 
		group by entidad,meas_round
		union 
		select entidad,meas_round,''N''
			from '+@ddbbData4G+'.dbo.'+@tableData4GDevice+' 
		group by entidad,meas_round
		union 
		select entidad,meas_round,''N'' --Entidades no aves ni roads
			from '+@ddbbCoverage+'.dbo.'+@tableCoverageInd+' 
		group by entidad,meas_round
		union 
		select entidad,meas_round,''N'' --Aves
			from '+@ddbbCoverage+'.dbo.'+@tableCoverageOut+' 
		group by entidad,meas_round
		union 
		select entidad,meas_round,''Y'' --Roads
			from '+@ddbbCoverageROAD+'.dbo.'+@tableCoverageInd+' 
		group by entidad,meas_round
')

--select * from _temp_Entities
	
delete lcc_entities_aggregated
--Insertamos las entidades-rondas existentes en el agregado que no estan contempladas aún
insert into lcc_entities_aggregated
select entity_name,meas_round,
	'N','N','N','N','N','N','N', --VDF
	'N','N','N','N','N','N','N', --OSP
	'N','N','N','N','N','N','N', --MUN
	'N','N','N','N','N','N','N', --ROAD
	is_Road
from _temp_Entities

delete lcc_entities_completed_Report
--Insertamos las entidades-rondas existentes en el agregado que no estan contempladas aún
insert into lcc_entities_completed_Report
select entity_name,meas_round,
	'N' --OSP
from _temp_Entities

drop table _temp_Entities