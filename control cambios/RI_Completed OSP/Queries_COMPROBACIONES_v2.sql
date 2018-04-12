select entidad,meas_round
from AggrData4G.dbo.lcc_aggr_sp_MDD_Data_DL_Thput_CE
where entidad = 'CALAHORRA'
group by entidad,meas_round

select entidad,meas_round
from AggrData4G.dbo.lcc_aggr_sp_MDD_Data_Youtube_HD
where entidad = 'CALAHORRA'
group by entidad,meas_round


select *
from lcc_entities_completed_Report r, lcc_entities_aggregated t
where r.entity_name=t.entity_name
and r.meas_round=t.meas_round
and r.entity_name like '%gandia%'
--group by meas_round
order by r.meas_round

select *
from lcc_entities_completed_Report r, lcc_entities_aggregated t
where r.entity_name=t.entity_name
and r.meas_round=t.meas_round
and Completed_OSP= 'N'
and r.meas_round like '%1617%'
--group by meas_round
order by r.meas_round



select *
from lcc_entities_aggregated 
where meas_round like 'Fy1516%'
and ([3G_Voice_MUN] = 'Y' or [3G_Data_MUN] = 'Y' or [4G_Voice_MUN] = 'Y' or [4G_Data_MUN] = 'Y' or Coverage_MUN='Y' --0
	or [3G_Voice_OSP] = 'Y' or [3G_Data_OSP] = 'Y' or [4G_Voice_OSP] = 'Y' or [4G_Data_OSP] = 'Y' or Coverage_OSP='Y') --0
order by meas_round,entity_name

select *
from lcc_entities_aggregated 
where meas_round like 'Fy1516%'
and (Coverage_MUN='Y' or Coverage_OSP='Y'or Coverage_VDF='Y')  --0
order by meas_round,entity_name


select 
	case 
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta todo'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta 4G'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta Voice'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta Data'

		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta 3G Voice y 4G Data'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G Data y 4G Voice'
		
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'Y' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G Voice'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G Data'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 4G Voice'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta 4G Data'

		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Solo 3G Voice'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Solo 3G Data'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Solo 4G Voice'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Solo 4G Data'
	end as 'Info',
	s.scope,
	a.* --a.entity_name, a.meas_round,
from lcc_entities_completed_Report e 
	inner join lcc_entities_aggregated a
	on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
	left join [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] s
			on e.entity_name=s.entity_name 
where e.Completed_OSP= 'N'
and e.meas_round like 'Fy1516%'
order by a.entity_name,a.meas_round

-----------------------------------------------------------------------------------------
select 
	case when Coverage_MUN='Y' or Coverage_OSP='Y'or Coverage_VDF='Y' then 'Y'
		else 'N' 
	end 'Hay cober',
	case 
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta todo VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'Y' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Esta todo VDF'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta 4G VDF'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta Voice VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta Data VDF'

		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta 3G Voice y 4G Data VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G Data y 4G Voice VDF'
		
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'Y' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G Voice VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G Data VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 4G Voice VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta 4G Data VDF'

		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Solo 3G Voice VDF'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Solo 3G Data VDF'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Solo 4G Voice VDF'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Solo 4G Data VDF'
	end as 'Info VDF',
	case 
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'N' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Falta todo OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'Y' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Esta todo OSP'
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'Y' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta 3G OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'N' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Falta 4G OSP'
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'N' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta Voice OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'Y' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Falta Data OSP'

		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'Y' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Falta 3G Voice y 4G Data OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'N' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta 3G Data y 4G Voice OSP'
		
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'Y' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta 3G Voice OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'Y' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta 3G Data OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'N' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta 4G Voice OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'Y' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Falta 4G Data OSP'

		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'N' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Solo 3G Voice OSP'
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'N' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Solo 3G Data OSP'
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'Y' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Solo 4G Voice OSP'
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'N' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Solo 4G Data OSP'
	end as 'Info OSP',
	case 
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'N' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Falta todo MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'Y' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Esta todo MUN'
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'Y' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta 3G MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'N' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Falta 4G MUN'
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'N' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta Voice MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'Y' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Falta Data MUN'

		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'Y' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Falta 3G Voice y 4G Data MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'N' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta 3G Data y 4G Voice MUN'
		
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'Y' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta 3G Voice MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'Y' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta 3G Data MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'N' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta 4G Voice MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'Y' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Falta 4G Data MUN'

		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'N' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Solo 3G Voice MUN'
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'N' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Solo 3G Data MUN'
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'Y' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Solo 4G Voice MUN'
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'N' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Solo 4G Data MUN'
	end as 'Info MUN',
	s.scope,
	a.* --a.entity_name, a.meas_round,
from lcc_entities_completed_Report e 
	inner join lcc_entities_aggregated a
	on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
	left join [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] s
			on e.entity_name=s.entity_name 
where e.Completed_OSP= 'N'
and (e.meas_round like 'Fy1617%'  or replace(e.meas_round,'OSP','FY') like 'Fy1617%')
order by a.entity_name,a.meas_round


select *
from lcc_entities_completed_Report
where Completed_OSP= 'N'
and meas_round not like 'Fy1617%'
and meas_round not like 'Fy1516%'


select e.entity_name, a.meas_round,
	case when Coverage_MUN='Y' or Coverage_OSP='Y'or Coverage_VDF='Y' then 'Y'
		else 'N' 
	end 'Hay cober',
	case 
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta todo VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'Y' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Esta todo VDF'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta 4G VDF'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta Voice VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta Data VDF'

		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta 3G Voice y 4G Data VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G Data y 4G Voice VDF'
		
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'Y' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G Voice VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 3G Data VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Falta 4G Voice VDF'
		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Falta 4G Data VDF'

		when [3G_Voice_VDF] = 'Y' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Solo 3G Voice VDF'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'Y' and [4G_Voice_VDF] = 'N' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Solo 3G Data VDF'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'Y' and [4G_Data_VDF] = 'N' and [4GDevice_Data_VDF] = 'N' then 'Solo 4G Voice VDF'
		when [3G_Voice_VDF] = 'N' and [3G_Data_VDF] = 'N' and [4G_Voice_VDF] = 'N' and ([4G_Data_VDF] = 'Y' or [4GDevice_Data_VDF] = 'Y') then 'Solo 4G Data VDF'
	end as 'Info VDF',
	case 
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'N' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Falta todo OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'Y' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Esta todo OSP'
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'Y' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta 3G OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'N' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Falta 4G OSP'
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'N' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta Voice OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'Y' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Falta Data OSP'

		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'Y' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Falta 3G Voice y 4G Data OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'N' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta 3G Data y 4G Voice OSP'
		
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'Y' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta 3G Voice OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'Y' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta 3G Data OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'N' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Falta 4G Voice OSP'
		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'Y' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Falta 4G Data OSP'

		when [3G_Voice_OSP] = 'Y' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'N' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Solo 3G Voice OSP'
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'Y' and [4G_Voice_OSP] = 'N' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Solo 3G Data OSP'
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'Y' and [4G_Data_OSP] = 'N' and [4GDevice_Data_OSP] = 'N' then 'Solo 4G Voice OSP'
		when [3G_Voice_OSP] = 'N' and [3G_Data_OSP] = 'N' and [4G_Voice_OSP] = 'N' and ([4G_Data_OSP] = 'Y' or [4GDevice_Data_OSP] = 'Y') then 'Solo 4G Data OSP'
	end as 'Info OSP',
	case 
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'N' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Falta todo MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'Y' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Esta todo MUN'
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'Y' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta 3G MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'N' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Falta 4G MUN'
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'N' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta Voice MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'Y' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Falta Data MUN'

		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'Y' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Falta 3G Voice y 4G Data MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'N' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta 3G Data y 4G Voice MUN'
		
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'Y' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta 3G Voice MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'Y' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta 3G Data MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'N' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Falta 4G Voice MUN'
		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'Y' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Falta 4G Data MUN'

		when [3G_Voice_MUN] = 'Y' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'N' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Solo 3G Voice MUN'
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'Y' and [4G_Voice_MUN] = 'N' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Solo 3G Data MUN'
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'Y' and [4G_Data_MUN] = 'N' and [4GDevice_Data_MUN] = 'N' then 'Solo 4G Voice MUN'
		when [3G_Voice_MUN] = 'N' and [3G_Data_MUN] = 'N' and [4G_Voice_MUN] = 'N' and ([4G_Data_MUN] = 'Y' or [4GDevice_Data_MUN] = 'Y') then 'Solo 4G Data MUN'
	end as 'Info MUN'
from lcc_entities_completed_Report  e 
	inner join lcc_entities_aggregated a
	on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
where e.Completed_OSP= 'N'
order by 1,2

select *
from lcc_entities_info
where entity_name='basauri'
