use AGRIDS_v2
--Backup
select * into lcc_ciudades_tipo_Project_V9_20180410
from lcc_ciudades_tipo_Project_V9

--Creamos tabla intermedia con las columnas nuevas [Resp_Sharing]/[Resp_Sharing_+]

CREATE TABLE [dbo].[lcc_ciudades_tipo_Project_V9_cambio_resp_sharing](
	[INE] [float] NULL,
	[NOMBRE] [nvarchar](255) NULL,
	[POB13] [float] NULL,
	[TIPO] [nvarchar](255) NULL,
	[SubTipo] [float] NULL,
	[COLOR] [nvarchar](255) NULL,
	[latitude] [float] NULL,
	[longitude] [float] NULL,
	[color_ok] [nvarchar](255) NULL,
	[Project] [nvarchar](255) NULL,
	[Priority] [nvarchar](255) NULL,
	[Type] [nvarchar](255) NULL,
	[Nombre_VODAFONE] [nvarchar](255) NULL,
	[Type_Meas] [nvarchar](255) NULL,
	[Entity_name] [nvarchar](255) NULL,
	[Latitude_WGS84] [float] NULL,
	[Longitude_WGS84] [float] NULL,
	[Provincia] [nvarchar](255) NULL,
	[Region_OSP] [nvarchar](5) NULL,
	[Region_VF] [nvarchar](7) NULL,
	[CCAA] [varchar](256) NULL,
	[Resp_sharing] [varchar](256) NULL,
	[Resp_sharing_+] [varchar](256) NULL,
	[SCOPE] [varchar](256) NULL,
	[RAN_VENDOR_VDF] [nvarchar](16) NULL,
	[RAN_VENDOR_MOV] [nvarchar](16) NULL,
	[RAN_VENDOR_OR] [nvarchar](16) NULL,
	[RAN_VENDOR_YOI] [nvarchar](16) NULL,
	[Rango_Pobl_1] [varchar](9) NULL,
	[Rango_Pobl_2] [varchar](9) NULL
)

--Insertamos filas de la tabla principal ciudades_tipo_project_v9 con el campo Tipo_Sharing_+ a NULO (nueva columnas, la Resp_Sharing solo se renombra)
insert into [lcc_ciudades_tipo_Project_V9_cambio_resp_sharing]
select [INE]
      ,[NOMBRE]
      ,[POB13]
      ,[TIPO]
      ,[SubTipo]
      ,[COLOR]
      ,[latitude]
      ,[longitude]
      ,[color_ok]
      ,[Project]
      ,[Priority]
      ,[Type]
      ,[Nombre_VODAFONE]
      ,[Type_Meas]
      ,[Entity_name]
      ,[Latitude_WGS84]
      ,[Longitude_WGS84]
      ,[Provincia]
      ,[Region_OSP]
      ,[Region_VF]
      ,[CCAA]
      ,[resp_sharing]
	  ,NULL
      ,[SCOPE]
      ,[RAN_VENDOR_VDF]
      ,[RAN_VENDOR_MOV]
      ,[RAN_VENDOR_OR]
      ,[RAN_VENDOR_YOI]
      ,[Rango_Pobl_1]
      ,[Rango_Pobl_2]
  FROM [dbo].[lcc_ciudades_tipo_Project_V9]
  
  --Lanzamos script resp_sharing_calculo2

  --Una vez rellena y echas las comprobaciones dropeamos la tabla principal y la sustituimos por la nueva
  drop table [lcc_ciudades_tipo_Project_V9]

  select * 
  into [lcc_ciudades_tipo_Project_V9]
  from [lcc_ciudades_tipo_Project_V9_cambio_resp_sharing]
