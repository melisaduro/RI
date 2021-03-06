USE [AddedValue]
GO
/****** Object:  StoredProcedure [dbo].[plcc_Update_Entity_aggregated]    Script Date: 13/07/2017 9:16:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [dbo].[plcc_Update_Entity_aggregated]

as

--Variable declarations
declare @ddbbCoverage varchar(256)
declare @ddbbVoice3G varchar(256)
declare @ddbbData3G varchar(256)
declare @ddbbVoice4G varchar(256)
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


declare @ind int = 1
declare @report varchar(50)

create table _temp_Report
(
	id int IDENTITY(1,1),
	report varchar (50)
)

insert into _temp_Report
select 'VDF'
union 
select 'OSP'
union 
select 'MUN'
union 
select 'ROAD'


set @ddbbCoverage = '[AGGRCoverage]'
set @ddbbCoverageROAD = '[AGGRCoverage_ROAD]'	
set @ddbbVoice3G = '[AggrVoice3G]'
set @ddbbVoice4G = '[AggrVoice4G]'
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
--Chequeamos la info agregada por cada report
--------------------------------------------------


set @ind=1

while @ind <= (select max(id) from _temp_Report)
begin
	set @report = (select report from _temp_Report where id=@ind)

	--3G VOZ
	exec ('update lcc_entities_aggregated
	set [3G_Voice_'+ @report + ']= case when t.entidad is null then ''N'' else ''Y'' end
	from lcc_entities_aggregated e
		left join (select entidad,meas_round
				from '+@ddbbVoice3G+'.dbo.'+@tableVoice+' 
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t
		on (t.entidad = e.entity_name and t.meas_round = e.meas_round)
	where e.is_Road = ''N''
	')
	--4G VOZ
	exec ('update lcc_entities_aggregated
	set [4G_Voice_'+ @report + ']= case when t.entidad is null then ''N'' else ''Y'' end
	from lcc_entities_aggregated e
		left join (select entidad,meas_round
				from '+@ddbbVoice4G+'.dbo.'+@tableVoice+' 
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t
		on (t.entidad = e.entity_name and t.meas_round = e.meas_round)
	where e.is_Road = ''N''
	')
	exec ('update lcc_entities_aggregated
	set [4G_Voice_'+ @report + ']= case when t.entidad is null then ''N'' else ''Y'' end
	from lcc_entities_aggregated e
		left join (select entidad,meas_round
				from '+@ddbbVoiceROAD+'.dbo.'+@tableVoice+' 
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t
		on (t.entidad = e.entity_name and t.meas_round = e.meas_round)
	where e.is_Road = ''Y''
	')

	--3G DATOS
	exec ('update lcc_entities_aggregated
	set [3G_Data_'+ @report + ']= case when t1.entidad is null or t2.entidad is null then ''N'' else ''Y'' end
	from lcc_entities_aggregated e
		left join (select entidad,meas_round
				from '+@ddbbData3G+'.dbo.'+@tableData+' 
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t1
		on (t1.entidad = e.entity_name and t1.meas_round = e.meas_round)
		left join (select entidad,meas_round
				from '+@ddbbData3G+'.dbo.'+@tableDataYTB+' 
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t2
		on (t2.entidad = e.entity_name and t2.meas_round = e.meas_round)
	where e.is_Road = ''N''
	')
	--4G DATOS (Exigimos que este agregada en tabla de thput y de ytb)
	exec ('update lcc_entities_aggregated
	set [4G_Data_'+ @report + ']= case when t1.entidad is null or t2.entidad is null then ''N'' else ''Y'' end
	from lcc_entities_aggregated e
		left join (select entidad,meas_round
				from '+@ddbbData4G+'.dbo.'+@tableData+' 
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t1
		on (t1.entidad = e.entity_name and t1.meas_round = e.meas_round)
		left join (select entidad,meas_round
				from '+@ddbbData4G+'.dbo.'+@tableDataYTB+' 
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t2
		on (t2.entidad = e.entity_name and t2.meas_round = e.meas_round)
	where e.is_Road = ''N''
	')
	exec ('update lcc_entities_aggregated
	set [4G_Data_'+ @report + ']= case when t1.entidad is null or t2.entidad is null then ''N'' else ''Y'' end
	from lcc_entities_aggregated e
		left join (select entidad,meas_round
				from '+@ddbbDataROAD+'.dbo.'+@tableData+' 
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t1
		on (t1.entidad = e.entity_name and t1.meas_round = e.meas_round)
		left join (select entidad,meas_round
				from '+@ddbbDataROAD+'.dbo.'+@tableDataYTB+' 
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t2
		on (t2.entidad = e.entity_name and t2.meas_round = e.meas_round)
	where e.is_Road = ''Y''
	')
	
	--4G DATOS DEVICE
	exec ('update lcc_entities_aggregated
	set [4GDevice_Data_'+ @report + ']= case when t.entidad is null then ''N'' else ''Y'' end
	from lcc_entities_aggregated e
		left join (select entidad,meas_round
				from '+@ddbbData4G+'.dbo.'+@tableData4GDevice+' 
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t
		on (t.entidad = e.entity_name and t.meas_round = e.meas_round)
	where e.is_Road = ''N''
	')
	
	--COBERTURA
	--Entidades no roads
	exec ('update lcc_entities_aggregated
	set Coverage_'+ @report + '= case when t1.entidad is null and t2.entidad is null then ''N'' else ''Y'' end
	from lcc_entities_aggregated e
		left join (select entidad,meas_round
				from '+@ddbbCoverage+'.dbo.'+@tableCoverageInd+'  --Entidades no aves ni roads
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t1
		on (t1.entidad = e.entity_name and t1.meas_round = e.meas_round)
		left join (select entidad,meas_round
				from '+@ddbbCoverage+'.dbo.'+@tableCoverageOut+'  --Aves
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t2
		on (t2.entidad = e.entity_name and t2.meas_round = e.meas_round)
	where e.is_Road = ''N''
	')
	--Roads
	exec ('update lcc_entities_aggregated
	set Coverage_'+ @report + '= case when t.entidad is null then ''N'' else ''Y'' end
	from lcc_entities_aggregated e
		left join (select entidad,meas_round
				from '+@ddbbCoverageROAD+'.dbo.'+@tableCoverageInd+' 
				where report_type = '''+ @report + '''
				group by entidad,meas_round
		) t
		on (t.entidad = e.entity_name and t.meas_round = e.meas_round)
	where e.is_Road = ''Y''
	')

	set @ind=@ind+1
end


drop table _temp_Report