USE [AddedValue]
GO
/****** Object:  StoredProcedure [dbo].[plcc_Update_Entity_completed_Report]    Script Date: 13/07/2017 9:14:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [dbo].[plcc_Update_Entity_completed_Report]

as
	--Inicializamos todas las entidades como no completadas (puede haber información agregada que haga que la entidad este completada que luego se borre)
	update lcc_entities_completed_Report
	set Completed_OSP= 'N'

	-----------------------------------------------------------------------------------------------------
	--CASO 1: Entidades solo Cobertura
	-----------------------------------------------------------------------------------------------------	
	--Chequeamos que tengan cobertura agregada
	print 'Caso 1: Entidades solo cobertura'
	update lcc_entities_completed_Report
	set Completed_OSP= 'Y'
	--select *
	from lcc_entities_completed_Report e
		inner join lcc_entities_aggregated a
			on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
		inner join [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] s
			on e.entity_name=s.entity_name and s.scope = 'ADD-ON CITIES COVERAGE'
	where a.Coverage_VDF = 'Y' or a.Coverage_OSP = 'Y' or a.Coverage_MUN = 'Y'


	-----------------------------------------------------------------------------------------------------
	--CASO 2: Entidades Calidad de FY1516
	-----------------------------------------------------------------------------------------------------	
	--(A): MC y SC: chequemos que tengan voz y datos (N4 ó S4) 3G/4G agregada
	print 'Caso 2: Entidades Calidad FY1516 NO aves-roads'
	update lcc_entities_completed_Report
	set Completed_OSP= 'Y'
	--select *
	from lcc_entities_completed_Report e
		inner join lcc_entities_aggregated a
			on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
		left join [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] s
			on e.entity_name=s.entity_name 
	where s.scope in ('SMALLER CITIES','MAIN CITIES')
		and a.meas_round like 'FY1516%'
		and ([3G_Voice_VDF] = 'Y' or [3G_Voice_OSP] = 'Y' or [3G_Voice_MUN] = 'Y')
		and ([3G_Data_VDF] = 'Y'  or [3G_Data_OSP] = 'Y'  or [3G_Data_MUN] = 'Y')
		and ([4G_Voice_VDF] = 'Y' or [4G_Voice_OSP] = 'Y' or [4G_Voice_MUN] = 'Y')
		and ([4G_Data_VDF] = 'Y'  or [4G_Data_OSP] = 'Y'  or [4G_Data_MUN] = 'Y' 
			or [4GDevice_Data_VDF] = 'Y'  or [4GDevice_Data_OSP] = 'Y'  or [4GDevice_Data_MUN] = 'Y')

	
	--(B): AVEs, ROADs, AoC, TC y PoCs: chequemos que tengan voz y datos 4G agregada
	print 'Caso 2: Entidades Calidad FY1516 aves-roads'
	update lcc_entities_completed_Report
	set Completed_OSP= 'Y'
	--select *
	from lcc_entities_completed_Report e
		inner join lcc_entities_aggregated a
			on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
		left join [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] s
			on e.entity_name=s.entity_name 
	where  (s.scope is null or s.scope in ('ADD-ON CITIES','TOURISTIC AREA','PLACES OF CONCENTRATION'))
		and a.meas_round like 'FY1516%'
		and ([4G_Voice_VDF] = 'Y' or [4G_Voice_OSP] = 'Y' or [4G_Voice_MUN] = 'Y')
		and ([4G_Data_VDF] = 'Y'  or [4G_Data_OSP] = 'Y'  or [4G_Data_MUN] = 'Y')
	
	

	-----------------------------------------------------------------------------------------------------
	--CASO 3: Entidades Calidad posteriores a FY1516
	-----------------------------------------------------------------------------------------------------
	--(A): No AVEs ni ROADs ni PoCs: chequemos que tengan voz y datos 3G/4G agregada y cobertura
	--Entidades de calidad de sólo orange, tendrán la info de calidad en meas_round=OSP% y de cobertura en meas_round=FY%
	print 'Caso 3: Entidades Calidad posteriores a FY1516 NO aves-roads'
	update lcc_entities_completed_Report
	set Completed_OSP= 'Y'
	--select *
	from lcc_entities_completed_Report e
		inner join (
			--Para desgloses de OSP, la info de cobertura la cogemos de FY tanto este agregado en la cober de H1 como en la de H2
			select a.[entity_name],a.[Meas_round]
				,a.[3G_Voice_VDF],a.[3G_Data_VDF],a.[4G_Voice_VDF],a.[4G_Data_VDF],a.[4GDevice_Data_VDF]
				,a.[3G_Voice_OSP],a.[3G_Data_OSP],a.[4G_Voice_OSP],a.[4G_Data_OSP],a.[4GDevice_Data_OSP]
				,a.[3G_Voice_MUN],a.[3G_Data_MUN],a.[4G_Voice_MUN],a.[4G_Data_MUN],a.[4GDevice_Data_MUN]
				,a.[is_Road]
				,case when a.meas_round like 'OSP%' and e.Coverage_VDF is not null then e.Coverage_VDF
					else a.Coverage_VDF end as 'Coverage_VDF'
				,case when a.meas_round like 'OSP%' and e.Coverage_OSP is not null then e.Coverage_OSP
					else a.Coverage_OSP end as 'Coverage_OSP'
				,case when a.meas_round like 'OSP%' and e.Coverage_MUN is not null then e.Coverage_MUN
					else a.Coverage_MUN end as 'Coverage_MUN'
			from  lcc_entities_aggregated a
				left join lcc_entities_aggregated e
					on (a.entity_name=e.entity_name 
						--Para desgloses de OSP reemplazamos OSP por FY y nos fijamos sólo en el año fiscal (es indiferente en que H este agragada la cober ya que es anual)
						and (a.meas_round like 'OSP%' and replace(left(a.meas_round,len(a.meas_round)-2),'OSP','FY')=left(e.meas_round,len(e.meas_round)-2)) 
					)
		) a
			on (e.entity_name=a.entity_name 
				--El desglose FY de cobertura en entidades de calidad de Orange debe actualizarse con la info de OSP creada en la tabla a (ya unificada la info de voz-datos con cober)
				--Los desglose FY que no se correspondan con calidad de Orange, no tendran desglose OSP y cruzaran con su mismo meas_round
				--Los desglose OSP cruzaran con su mismo meas_round (ya unificada en tabla a la info de cober)
				and ((e.meas_round like 'FY%' and 
						(replace(left(e.meas_round,len(e.meas_round)-2),'FY','OSP')=left(a.meas_round,len(a.meas_round)-2) or e.meas_round=a.meas_round)) 
					or
						(e.meas_round not like 'FY%' and e.meas_round=a.meas_round)
				))
		left join [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] s
			on e.entity_name=s.entity_name 
	where s.scope <> 'ADD-ON CITIES COVERAGE' and s.scope <> 'PLACES OF CONCENTRATION' 
		and a.meas_round not like 'FY1516%'
		and ([3G_Voice_VDF] = 'Y' or [3G_Voice_OSP] = 'Y' or [3G_Voice_MUN] = 'Y')
		and ([3G_Data_VDF] = 'Y'  or [3G_Data_OSP] = 'Y'  or [3G_Data_MUN] = 'Y')
		and ([4G_Voice_VDF] = 'Y' or [4G_Voice_OSP] = 'Y' or [4G_Voice_MUN] = 'Y')
		and ([4G_Data_VDF] = 'Y'  or [4G_Data_OSP] = 'Y'  or [4G_Data_MUN] = 'Y')
		and (Coverage_VDF = 'Y' or Coverage_OSP = 'Y' or Coverage_MUN = 'Y')

	
	--(B): ROADs: chequemos que tengan voz y datos 4G agregada y cobertura (no son entidades de calidad de Orange por lo que su meas_round es igual en calidad y en cober)
	print 'Caso 3: Entidades Calidad posteriores a FY1516 Carreteras'
	update lcc_entities_completed_Report
	set Completed_OSP= 'Y'
	--select *
	from lcc_entities_completed_Report e
		inner join lcc_entities_aggregated a
			on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
		left join [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] s
			on e.entity_name=s.entity_name 
	where s.scope is null -- AVEs y ROADs no están en [lcc_ciudades_tipo_Project_V9]
		and a.meas_round not like 'FY1516%'
		and is_road = 'Y' -- Solo entran carreteras. Necesitamos cobertura
		and ([4G_Voice_VDF] = 'Y' or [4G_Voice_OSP] = 'Y' or [4G_Voice_MUN] = 'Y')
		and ([4G_Data_VDF] = 'Y'  or [4G_Data_OSP] = 'Y'  or [4G_Data_MUN] = 'Y')
		and (Coverage_VDF = 'Y' or Coverage_OSP = 'Y' or Coverage_MUN = 'Y')



	--(C): PoCs: chequemos que tengan voz y datos 4G agregada 
	print 'Caso 3: Entidades Calidad posteriores a FY1516 aves-roads'
	update lcc_entities_completed_Report
	set Completed_OSP= 'Y'
	--select *
	from lcc_entities_completed_Report e
		inner join lcc_entities_aggregated a
			on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
		left join [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] s
			on e.entity_name=s.entity_name 
	where s.scope = 'PLACES OF CONCENTRATION'
		and a.meas_round not like 'FY1516%'
		and ([4G_Voice_VDF] = 'Y' or [4G_Voice_OSP] = 'Y' or [4G_Voice_MUN] = 'Y')
		and ([4G_Data_VDF] = 'Y'  or [4G_Data_OSP] = 'Y'  or [4G_Data_MUN] = 'Y')

	--(D): AVEs 1617: chequemos que tengan voz y datos 4G agregada y cobertura 
	print 'Caso 1: AVES Calidad FY1617_H2 aves'
	update lcc_entities_completed_Report
	set Completed_OSP= 'Y'
	from lcc_entities_completed_Report e
		inner join lcc_entities_aggregated a
			on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
		left join [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] s
			on e.entity_name=s.entity_name 
	where s.scope is null -- Road o AVE
		and a.meas_round like 'FY1617%'-- Sólo H2 FY1617 hay que chequear cober (H1 está en una excepción posterior)
		and is_road='N' 
		and ([4G_Voice_VDF] = 'Y' or [4G_Voice_OSP] = 'Y' or [4G_Voice_MUN] = 'Y')
		and ([4G_Data_VDF] = 'Y'  or [4G_Data_OSP] = 'Y'  or [4G_Data_MUN] = 'Y')
		and (Coverage_VDF = 'Y' or Coverage_OSP = 'Y' or Coverage_MUN = 'Y')






	-----------------------------------------------------------------------------------------------------
	--CASO 4: Carreteras de sólo cobertura (no A1,.., A7), se agregan sólo como ROAD
	-----------------------------------------------------------------------------------------------------	
	--Chequeamos que tengan cobertura agregada
	print 'Caso 1: Entidades solo cobertura'
	update lcc_entities_completed_Report
	set Completed_OSP= 'Y'
	--select *
	from lcc_entities_completed_Report e
		inner join lcc_entities_aggregated a
			on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
	where a.Coverage_ROAD = 'Y'  --La coverage tipo ROAD sólo se agrega para carreteras no principales
		and is_road='Y'
		
		
	-----------------------------------------------------------------------------------------------------
	--CASO 5: AVEs 1718 no tendrán cobertura
	-----------------------------------------------------------------------------------------------------	 
	print 'Caso 1: AVES Calidad FY1718 aves'
	update lcc_entities_completed_Report
	set Completed_OSP= 'Y'
	from lcc_entities_completed_Report e
		inner join lcc_entities_aggregated a
			on (a.entity_name=e.entity_name and a.meas_round = e.meas_round)
		left join [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] s
			on e.entity_name=s.entity_name 
	where s.scope is null -- Road o AVE
		and a.meas_round like 'FY1718%'-- Son los AVES del 1718 los que no sacaremos su cobertura
		and is_road='N' -- Campo que pone Ceci para distinguir carreteras. Así diferencia AVE y Carretera
		and ([4G_Voice_VDF] = 'Y' or [4G_Voice_OSP] = 'Y' or [4G_Voice_MUN] = 'Y')
		and ([4G_Data_VDF] = 'Y'  or [4G_Data_OSP] = 'Y'  or [4G_Data_MUN] = 'Y')