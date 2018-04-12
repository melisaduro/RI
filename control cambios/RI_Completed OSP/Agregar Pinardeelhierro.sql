
--Insertar PINARDEELHIERRO en lcc_entities_info para que salga como completada

--backup
select *
into [AddedValue].[dbo].[lcc_entities_info_backup ]
from [AddedValue].[dbo].[lcc_entities_info]

--Insertar la linea en la tabla

  insert into [AddedValue].[dbo].[lcc_entities_info] (entity_name, pedanias, only_cover) 
  --select * from lcc_entities_info (entity_name, pedanias, only_cover) 
  values ( 'PINARDEELHIERRO', 'N', 'Y');

  --Comprobar
  select * from lcc_entities_info where entity_name = 'PINARDEELHIERRO'
 
  --Borrar tabla backup
  drop table lcc_entities_info_backup 