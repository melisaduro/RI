--Comprobaciones tabla Ceci RI. Completed_OSP='N'

--Comprobaciones tabla Ceci Completed_OSP='N' FY1516. Deberían salir 28 entidades, ya chequeadas.
select   *
from lcc_entities_completed_Report e 
	inner join lcc_entities_aggregated a
	on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
	left join AGRIDS_v2.dbo.lcc_ciudades_tipo_Project_V9 c
	on (e.entity_name=c.entity_name)
where e.Completed_OSP= 'N'
and e.meas_round like '%1718%'
order by a.entity_name,a.meas_round

select entidad,*
from AGGRCoverage.dbo.lcc_aggr_sp_MDD_Coverage_All_Curves
where entidad like '%AVE-Madrid-Valladolid-R6%'
and mnc=03


select * from AGRIDS_v2.dbo.lcc_ciudades_tipo_Project_V9
where entity_name like'%-%'




--Comprobaciones tabla Ceci Completed_OSP='N' FY1617. 
select *
from lcc_entities_completed_Report e 
	inner join lcc_entities_aggregated a
	on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
	left join [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] s
			on e.entity_name=s.entity_name 
where a.entity_name like '%A1_IRUN_R6%'
order by a.meas_round, a.entity_name

----------------------------------------------------------------------------
--Tabla Ceci comprobaciones RI

select * from lcc_entities_completed_report e
inner join lcc_entities_aggregated a 
on (a.entity_name=e.entity_name and a.Meas_round=e.Meas_round)
where a.entity_name in ('PINARDEELHIERRO')
--and e.Completed_OSP= 'Y'
order by  a.entity_name,a.meas_round

--Agregado calidad datos

select type_scope, scope, report, meas_round,entidad,[database],date_reporting,week_reporting, report_type, aggr_type
from [AGGRData4G].dbo.lcc_aggr_sp_MDD_Data_DL_Thput_NC a, [AGRIDS].dbo.lcc_dashboard_info_scopes_NEW d
where  a.entidad=d.entities_bbdd
and a.report_type=d.report
and a.entidad in  ('donosti')
group by  type_scope, scope, report,meas_round,entidad,[database],date_reporting,week_reporting, report_type, aggr_type
order by entidad, date_reporting

--Agregado calidad voz

select meas_date,type_scope, scope, report,meas_round,entidad,[database],date_reporting,week_reporting, report_type, aggr_type
from [AGGRVoice3G].dbo.lcc_aggr_sp_MDD_Voice_Llamadas a, [AGRIDS].dbo.lcc_dashboard_info_scopes_NEW d
where a.entidad=d.entities_bbdd
and a.report_type=d.report
and a.entidad in  ('oviedo')
group by meas_date,type_scope, scope, report, meas_round,entidad,[database],date_reporting,week_reporting, report_type, aggr_type
order by entidad, date_reporting

--Agregado cobertura

select type_scope, scope, report,MEAS_ROUND,entidad,[database],date_reporting,week_reporting, report_type, aggr_type
from [AGGRCoverage].DBO.lcc_aggr_sp_MDD_Coverage_All_Curves a, [AGRIDS].dbo.lcc_dashboard_info_scopes_NEW d
where a.entidad=d.entities_bbdd
and a.report_type=d.report
and a.Entidad in  ('barcelona')
group by type_scope, scope, report,MEAS_ROUND,entidad,[database],date_reporting,week_reporting, report_type, aggr_type
order by entidad, date_reporting

--select MEAS_ROUND,entidad,[database],date_reporting,week_reporting, report_type, aggr_type
--from [AGGRCoverage].DBO.lcc_aggr_sp_MDD_Coverage_All_Curves
--where Entidad =  ('vilaseca')

--select * from [AGRIDS].dbo.lcc_dashboard_info_scopes_NEW where entities_bbdd like '%hierro%' --info scopes VDF_MUN

select meas_date,meas_round,entidad,[database],date_reporting,week_reporting, report_type, aggr_type
from [AGGRVoice3G].dbo.lcc_aggr_sp_MDD_Voice_Llamadas 
where entidad in  ('Algemesi'
,'Elda'
,'Leioa'
,'Moguer'
,'Pontevedra'
,'SantAndreudelabarca'
,'Sestao'
,'Utiel'
,'Almonte'
,'Arroyomolinos'
,'Igualada'
,'LavalldUixo'
,'LaVillajoyosa'
,'langreo'
,'Leganes'
,'Leioa'
,'Manresa'
,'Marin'
,'Montcadaireixac'
,'Portugalete'
,'Torre-Pacheco'
,'Portugalete')
and report_type='MUN'
group by meas_date,meas_round,entidad,[database],date_reporting,week_reporting, report_type, aggr_type
order by entidad

select meas_date,meas_round,entidad,[database],date_reporting,week_reporting, report_type, aggr_type
from [AGGRVoice4G].dbo.lcc_aggr_sp_MDD_Voice_Llamadas 
where entidad in  ('almonte')
and report_type='MUN'
group by meas_date,meas_round,entidad,[database],date_reporting,week_reporting, report_type, aggr_type
order by entidad

-------------------------Comprobaciones agregado--------------------------------------

use FY1617_Voice_Rest_3G_H1_3
select * from filelist where collectionname like '%laredo%'

declare @entidad as varchar (256)='ALDAIA'

select [database],entidad,aggr_type, meas_date,date_reporting,week_reporting,report_type,meas_round
from [AGGRVoice4G].dbo.lcc_aggr_sp_MDD_Voice_Llamadas
where entidad like '%ALDAIA%'
group by [database],entidad,aggr_type, meas_date,date_reporting,week_reporting,report_type,meas_round
order by 4

--select [database],entidad,aggr_type,meas_Date,meas_week,date_reporting,week_reporting,report_type,meas_round
--from [AGGRData3G].dbo.lcc_aggr_sp_MDD_Data_DL_Thput_CE
--where entidad like '%carmona%'
--group by [database],entidad,aggr_type,meas_Date,meas_week,date_reporting,week_reporting,report_type,meas_round
--order by 1

select [database],entidad,aggr_type,meas_Date,meas_week,date_reporting,week_reporting,report_type,meas_round
from [AGGRData4G].dbo.lcc_aggr_sp_MDD_Data_Youtube_HD
where entidad= @entidad
group by [database],entidad,aggr_type,meas_Date,meas_week,date_reporting,week_reporting,report_type,meas_round
order by 1


select * from [AGRIDS].[dbo].[lcc_dashboard_info_scopes_NEW]
where scope = 'PLACES OF CONCENTRATION' and report='MUN'
order by 4

SEV-RLW
VLC-APT


