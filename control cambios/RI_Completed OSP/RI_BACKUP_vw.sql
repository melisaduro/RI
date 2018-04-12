select entity,meas_date,meas_week, report_type,meas_round,round,last_measurement_vdf,last_measurement_osp,last_measurement_osp_noComp,id_osp, id_osp_noComp,id_vdf
from [QLIK].[dbo].[_RI_Voice_Completed_Qlik]
 where last_measurement_osp=1 
group by entity,meas_date,meas_week, report_type,meas_round,id_osp,id_vdf,round,last_measurement_vdf,last_measurement_osp,last_measurement_osp_noComp,id_osp, id_osp_noComp,id_vdf
having count(distinct report_type)=2
order by meas_date,meas_round

 select entity,count(distinct report_type) as 'numReport',meas_round,meas_date
 from [QLIK].[dbo].[_RI_Data_Completed_Qlik]
 where last_measurement_osp=1 
 group by entity,meas_round,meas_date
 having count(distinct report_type)=2
 order by meas_round,meas_date

 select entity,count(distinct report_type) as 'numReport',report_type,meas_round,meas_date,meas_tech
 from [QLIK].[dbo].[_RI_Voice_Completed_Qlik] t
 where last_measurement_osp=1 
 and entity like '%mad-%'
 group by entity,meas_round,meas_date,report_type,meas_tech
 --having count(distinct report_type)=2
 order by 1,6

 select pob13,entity_name
from agrids_v2.dbo.lcc_ciudades_tipo_Project_V9
where entity_name='TIRAJANA'

