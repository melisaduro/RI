USE FY1718_TEST_CECI
--GO
--/****** Object:  StoredProcedure [dbo].[sp_lcc_abrir_cobertura_FY1718]    Script Date: 04/01/2018 16:09:45 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO


--ALTER procedure [dbo].[sp_lcc_abrir_cobertura_FY1718] (
--	@ruta_entidades as varchar(4000) 
--	)
--as

-- TESTING VARIABLES
 declare @ruta_entidades as varchar (4000)='F:\VDF_Invalidate\responsable_sharing.xlsx'

-- Importamos el excel que contiene el nombre de todas las ciudades a agregar

exec sp_lcc_dropifexists '_ciudades'

-- Cogemos la informacion de la entidad del Excel en red
exec  [dbo].[sp_importExcelFileAsText] @ruta_entidades, 'cities','_ciudades'


-- Le creamos un identificador a cada ciudad para luego crear un bucle

select identity(int,1,1) id,*
into #iterator
from [dbo].[_ciudades]


--Mostramos las ciudades que se agregaran

 --select * from #iterator
 --select * from agrids_v2.dbo.lcc_ciudades_tipo_Project_V9_cambio_resp_sharing
 --Comenzamos el bucle con todas las ciudades a agregar

update agrids_v2.dbo.lcc_ciudades_tipo_Project_V9_cambio_resp_sharing 
set Resp_sharing=t2.Tipo_Sharing, [Resp_Sharing_+]=t2.[Tipo_Sharing_+]
from agrids_v2.dbo.lcc_ciudades_tipo_Project_V9_cambio_resp_sharing t1, #iterator t2
where t1.ine=t2.ine

--update agrids_v2.dbo.lcc_ciudades_tipo_project_v9_williams
--set resp_sharing=t2.tipo
--from agrids_v2.dbo.lcc_ciudades_tipo_project_v9_williams t1, #iterator t2
--where t1.ine=t2.ine


--select t1.*, t2.[Tipo_Sharing] as 'Responsable_Sharing',t2.[Tipo_Sharing_+] as 'Responsable_Sharing_+'
----into agrids_v2.dbo.lcc_ciudades_tipo_project_v9_williams_20180104
--from agrids_v2.dbo.lcc_ciudades_tipo_Project_V9_cambio_resp_sharing t1, #iterator t2
--where t1.ine=t2.ine

--select count(1) from agrids_v2.dbo.lcc_ciudades_tipo_project_v9
--select count(1) from agrids_v2.dbo.lcc_ciudades_tipo_project_v9_20180104

--select count(1) from agrids_v2.dbo.lcc_ciudades_tipo_project_v9_williams
--select count(1) from agrids_v2.dbo.lcc_ciudades_tipo_project_v9_williams_20180104


drop table #iterator