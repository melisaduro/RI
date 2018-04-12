select entity,meas_date,meas_week, report_type,meas_round,round,last_measurement_vdf,last_measurement_osp,last_measurement_osp_noComp,id_osp, id_osp_noComp,id_vdf
from [QLIK].[dbo].[_RI_Voice_Completed_Qlik]
 where 
entity in ('A4-CAD','A7-ALG')
and meas_tech like'%road%cover%'
group by entity,meas_date,meas_week, report_type,meas_round,id_osp,id_vdf,round,last_measurement_vdf,last_measurement_osp,last_measurement_osp_noComp,id_osp, id_osp_noComp,id_vdf
order by meas_date,meas_round

select *
from [QLIK].[dbo].[_RI_Data_Completed_Qlik]

select vendor_VF, vendor_3G_MV, vendor_4G_MV, vendor_OR, provincia, region_VF,region_OSP
from agrids.dbo.lcc_parcelas
group by vendor_VF, vendor_3G_MV, vendor_4G_MV, vendor_OR, provincia, region_VF, region_OSP
order by 5

select vendor_VF, provincia, ciudad
from agrids.dbo.lcc_parcelas
group by vendor_VF, provincia, ciudad
order by 2

select *
from agrids.dbo.lcc_parcelas
where ciudad is null

select *
from FY1617_Coverage_Union_ROAD_H2.dbo.lcc_Union_Status_temp

