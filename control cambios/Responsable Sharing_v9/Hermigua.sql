use AGRIDS_v2

begin transaction

--Borramos Hermigua, ya que es una entidad Williams que no entraba en el scope finalmente
use AGRIDS_v2
delete from lcc_ciudades_tipo_project_v9
where entity_name='hermigua'

use AGRIDS
delete from lcc_dashboard_info_scopes_NEW 
where entities_bbdd='HERMIGUA'

commit


