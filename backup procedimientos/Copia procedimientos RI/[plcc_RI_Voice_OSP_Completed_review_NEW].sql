USE [AddedValue]
GO
/****** Object:  StoredProcedure [dbo].[plcc_RI_Voice_OSP_Completed_review_CST]    Script Date: 13/07/2017 9:29:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[plcc_RI_Voice_OSP_Completed_review_CST] 
	@result as varchar(5),	--'Q' para Qlik			- lanza los procs y crea las tablas necesarias para QLIK
							--'D' para DASH			- solo las ultimas medidas y agregados de carreteras en funcion de @rollwindowRoad y @rollwindowAve
							--'E' para excel del RI	- todas las medidas - en el Excel se podra filtrar por LastMeasurement=1 para la ultima medida
	
	-- Ventanas deslizantes de las rondas a elegira para CARRETERAS y AVES:
	@rollwindowRoad as int,
	@rollwindowAve as int,

	@client as int,		-- Cliente final de entrega:+
							--VDF – borra columnas de IDs relativas a OSP  
							--OSP – ídem y además elimina la info de VOLTE para que no salga

	@isCompleted as varchar(10)		-- No aplica para VDF
											-- 'Y'		-- solo tienen en cuenta las entidades COMPLETADAS para OSP
											-- 'N'		-- tienen en cuenta todas las medidas, COMPLETADAS o no, para OSP
as


---------------------------------------
---------- Testing Variables ----------
---------------------------------------
--declare @result as varchar(5)= 'Q'		----'Q' para Qlik			- lanza los procs y crea las tablas necesarias para QLIK
--										----'D' para DASH			- solo las ultimas medidas y agregados de carreteras en funcion de @rollwindowRoad y @rollwindowAve
--										----'E' para excel del RI	- todas las medidas - en el Excel se podra filtrar por LastMeasurement=1 para la ultima medida
	
------	 Ventanas deslizantes de las rondas a elegira para CARRETERAS y AVES:
--declare @rollwindowRoad as int = 4
--declare @rollwindowAve as int = 3

--declare @client as int=0	-- Cliente final de entrega:
--								VDF – borra columnas de IDs relativas a OSP 
--								OSP – ídem y además elimina la info de VOLTE para que no salga

--declare @isCompleted as varchar(10)='Y'		---- No aplica para VDF
--											 ----'Y'		-- solo tienen en cuenta las entidades COMPLETADAS para OSP
--											 ----'N'		-- tienen en cuenta todas las medidas, COMPLETADAS o no, para OSP
-----------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------
 --COMENTARIOS:

--	1) Se anula la info de VOLTE en medidas de 4G/3G
--	2) Se anula la info de NB en medidas M2M (el calltype viene en funcion de la bbdd de momento no se agrega)
--	   Se anula la info de WB en medidas M2F (el calltype viene en funcion de la bbdd de momento no se agrega)
--	4) Se deja la info relativa a MO/MT (intentos, cst) en llamadas M2M 
--	5) Se anulan WB AMR Only	WB_AMR_Only_Avg para YOI, ya que hay entidades agregadas con valor, y tiene q ser nulo
--	6) Se añade las ventanas deslizantes para el número de rondas a escoger para ROADs y AVEs
--	7) Se añae CR_Affected_Calls, pero se anula para todo lo que no sea AVE (en el BS el CR esta desactivdo como tal, solo funciona en los FR y de mommento interesan solo los AVEs)
--	8) Se incluye la Region_VF y Region_OSP en todas las entidades (Calidad y Cober)
--		para el @result='Q' de momento solo hace falta el Region_Road - por eso se crea una columna nueva para todas
--		para @result='D'/'E' nos quedamos SOLO con la Region correspondiente a @client y se sustituye ademas el valor para que sea del tipo ZonaX
--	9) Para el last_Measuremente, se realiza la ordenacion por cast(replace(meas_Week,'W','') as int) desc ya que de la otra forma ordena erroneamente al considerarlos como string (WX)

--	10) Se tienen en cuenta un nuevo 'report_type=ROAD'
--	Se trata de medidas de cobertura en carreteras extras para OSP solo. 
--	Se tratan de manera especial en el agregado.
--	Para mantener el formato con carreteras principales, en la parte de cobertura, se añade la coletiila -RX a las medidas que tengan este repot_type
--  Se tienen en cuenta tmb a la hora de presentar resutlado:
--		1) a VDF se borran
--		2) se tiene en cuenta que no existen en la tabla de AGRIDs.dbo.vlcc_dashboard_info_scopes_NEW - ENTITIES_DASHBOARD saldría a null

-- 11)	UPDATE_parcelas_sin_info: No se pueden dejar con codigoINE=99999 porque eso es de Indoor

-- 12)  Railways: Se anula el código_ine antes de todo el tema de unificaciones y demás, ya que codig_ine=99999 = INDOOR
-- 13)	Se cambia la forma de obtener las regiones	-> En vez de cogerse del agregado (que viene de lcc_parcelas) y tener que agrupar y modificar las tablas bases del RI, se cogen una vez unificados todas las tablas intermedias 
--			b.	Primero:
--				i.	Se asignan solo para AVEs y ROADs, en función del código_ine obtenido de vlcc_parcelas_osp -> Provincia, CCAA, Region_Road_VF, Region_Road_OSP, Region_VF y Region_OSP
--				ii.	Estos campos de vlcc_parcelas_OSP, viene de lcc_parcelas
--				iii.	Los campos:      
--							1.	Region_Road_VF, Region_Road_OSP		-> son para Qlik, solo tendran la info de carreteras, resto de entidades a null
--							2.	Region_VF y Region_OSP				-> tendrán la info para todo, en carreteras coincidirán con Region_Road_VF, Region_Road_OSP
--			c.	Segundo:
--				i.	Se unifica el código INE para todas las entidades menos AVEs y ROADs, tras lo cual, se rellenara esta información en estas entidades a partir de la V9
--			d.	Tercero: 
--					Se anula el valor de los códigos INE en carreteras y Aves, teniendo ya la info de todo
--			e.	Cuarto: 
--					Se agrupa la info por código ine de las entidades, que ahora es único para las entidades (V9) y se concatenan los KPIS de la cober ponderada por población a nivel de entidad ( mismo info en cada tipo de environment).

-- 14)	En lcc_parcelas, la info de Region viene con formato RX (tanto para VF o para OSP).
--		En V9, tenemos formato RegionX para VF y ZonaX para OSP -> En el punto 16 del RI se deja todo con formato RX (para que cuadren todos).
--		A la hora de sacar la info en los Excel, se sustituye por el formato ZonaX para ambos operadores

-- 15)	Para el cáclo del last_measurement de OSP, el meas_orderse calcula de la siguiente forma:
--		a) row_number() over 
--				(partition by  entity, mnc, meas_tech
--					order by case when max(id_osp) = 1 then max(id_osp) end DESC, meas_round DESC, case when report_type = 'MUN' then report_type end DESC,
--						meas_date DESC, cast(replace(meas_Week,'W','') as int) DESC					 
--				 ) as meas_order_osp 
--		Así, se cogera siempre la medida de la ultima fase:
--			* cd solo haya un reporte (y si está marcado como completado), lo cogera sea VDF o MUN
--			* cd haya los dos, cogera ordenadno por MUN-OSP-VDF
--		EXCEPCION en la Cobertura de ROADS y AVES, ya que cada operadro tiene sus propios umbrales. 
--		Para ello, se descartan las medidas con reporte VDF para estos scopes, para el calculo del meas_order. En cuyo caso se anula dicho campo

-- 16)	Se añaden los campos coverageXG_den_ProbCob, para usarse como denominador
--		Los AVES se agregan solo por Outdoor, y no tienen info de PCI (valor nulo que mete 0 en el calculo final del RI).
--		Esto hace que en las ppt cuenten esos 0.

--	17) Se borra el campo Report_Type para presentar en el excel


-- ************************************************************************************************************************************
--	Para ejecutar PRUEBAS que no molesten a QLIK, se puede sustituir '_RI_Voice' por _RI_Voice_VXX:
--			* TODAS las tablas involcradas en el proc empiezan por esta coletilla
--			* el codigo de replicas chequea si existe dicha coletilla para crear su tabla final con ella o no
-- ************************************************************************************************************************************

---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------EXPLICACIÓN CÓDIGO------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------

  /*
  Se obtienen todos los KPIs necesarios para el RI y Qlik, tanto de 3G, 4G como 4GOnly para todos los entornos y operadores (Vodafone y Orange)
  Cuenta con un:
	* id_vdf que se pone a uno cuando la medida es tipo "VDF"
	* id_osp que se pone a 1 con la última medida Completada (medida en 3G, 4G y cobertura) 
		independientemente de que la medida sea tipo "VDF" o tipo "MUN", aunque éstas tendrán prioridad ante las medidas Vodafone.
	* id_osp_noComp que sirve para coger todas las medidas para OSP, completadas o no.

  Al final del código se pone un indicador de "última medida" tanto para Vodafone como para Orange, ya que los criterios para ambos son distintos.
	* Para Vodafone este indicador se pondrá a uno con la última medida vodafone. 
	* Para Orange se pondrá a 1 con la última medida completada, principalmente, si hubiese, por Municipios, 
		sino se quedaría con la última medida Vodafone completada.
	*/

---------------------------------------------------------------------------------------------------------------------------------------

-- ************************************************************************************************************************************
if @result='Q'	-- trabajamos para Qlik				
begin

	---------------------------------------
	-- Se borra la _RI_Voice_Ejecucion para iniciar de nuevo:
	exec sp_lcc_dropifexists '_RI_Voice_Ejecucion'

	--------------------------------------------------------------------------
	-- TABLA de SEGUIMIENTO de la ejecución del RI:
	if (select name from sys.tables where type='u' and name='_RI_Voice_Ejecucion') is null
	begin
		CREATE TABLE [dbo].[_RI_Voice_Ejecucion](
			[Status] [varchar](255) NULL,
			[Date] [datetime] NULL
		) ON [primary]

		insert into [dbo].[_RI_Voice_Ejecucion]
		select 'Inicio ejecucion RI Voz', getdate()
	end

	--------------------------------------------------------------------------
	-- Se borran las tablas por si quedara una ejecucion incompleta:
	exec dbo.sp_lcc_dropifexists '_RI_Voice_c'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_m'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cst'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cst_csfb'

	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober2G'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober3G'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober4G'

	exec dbo.sp_lcc_dropifexists '_RI_Voice_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober3G_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober2G_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober4G_Pob_Entidad'

	exec dbo.sp_lcc_dropifexists '_RI_Voice_base'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base1'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result1'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result_INE_only'

	exec dbo.sp_lcc_dropifexists '_RI_Voice_base_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_i_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base1_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result1_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result2_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result1_info'

	exec dbo.sp_lcc_dropifexists '_RI_Voice_base_report_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base_x'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_last'

	exec dbo.sp_lcc_dropifexists '_RI_Voice_last_osp'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_last_vf'


	---------------------------------------
	CREATE TABLE _RI_Voice_c (
		[calltype] [nvarchar](256) NULL,
		[codigo_ine] [float] NULL,
		[vf_environment] [nvarchar](255) NULL,
		[mnc] [varchar](2) NULL,
		[meas_round] [varchar](256) NULL,
		[meas_date] [varchar](256) NULL,
		[meas_week] [varchar](256) NULL,
		[meas_Tech] [varchar](256) NOT NULL,
		[info_available] [float] NOT NULL,
		[vf_entity] [varchar](256) NULL,
		[Report_Type] [varchar](256) NULL,
		[aggr_type] [varchar](256) NULL,
		[MOC_Calls] [float] NULL,
		[MTC_Calls] [float] NULL,
		[MOC_Blocks] [float] NULL,
		[MTC_Blocks] [float] NULL,
		[MOC_Drops] [float] NULL,
		[MTC_Drops] [float] NULL,
		[Calls] [float] NULL,
		[Blocks] [float] NULL,
		[Drops] [float] NULL,
		[CR_Affected_Calls] [float] NULL,
		[Call_duration_3G] [float] NULL,
		[Call_duration_2G] [float] NULL,
		[Call_duration_tech_samples] [float] NULL,
		[CSFB_to_GSM_samples] [float] NULL,
		[CSFB_to_UMTS_samples] [float] NULL,
		[CSFB_samples] [float] NULL,
		[AMR_FR_samples] [float] NULL,
		[AMR_HR_samples] [float] NULL,
		[AMR_WB_samples] [float] NULL,
		[FR_samples] [float] NULL,
		[EFR_samples] [float] NULL,
		[HR_samples] [float] NULL,
		[codec_samples] [float] NULL,
		[NUMBERS OF CALLS Non Sustainability (NB)] [float] NULL,
		[NUMBERS OF CALLS Non Sustainability (WB)] [float] NULL,
		[Calls_Started_2G_WO_Fails] [float] NULL,
		[Calls_Started_3G_WO_Fails] [float] NULL,
		[Calls_Started_4G_WO_Fails] [float] NULL,
		[Calls_Mixed] [float] NULL,
		[VOLTE_SpeechDelay_Num] [float] NULL,
		[VOLTE_SpeechDelay_Den] [float] NULL,
		[VOLTE_Calls_Started_Ended_VOLTE] [float] NULL,
		[VOLTE_Calls_withSRVCC] [float] NULL,
		[VOLTE_Calls_is_VOLTE] [float] NULL,
		--[Region_Road_VF]	[nvarchar](256)	NULL, 
		--[Region_Road_OSP]	[nvarchar](256)	NULL,
		[ASideDevice] [nvarchar](256) NULL,
		[BSideDevice] [nvarchar](256) NULL,
		[SWVersion] [nvarchar](256) NULL

	) ON [PRIMARY]


	CREATE TABLE _RI_Voice_m (
		[calltype] [nvarchar](256) NULL,
		[codigo_ine] [float] NULL,
		[vf_environment] [nvarchar](256) NULL,
		[mnc] [varchar](2) NULL,
		[meas_round] [varchar](256) NULL,
		[meas_date] [varchar](256) NULL,
		[meas_week] [varchar](256) NULL,
		[meas_Tech] [varchar](256) NOT NULL,
		[info_available] [float] NOT NULL,
		[vf_entity] [varchar](256) NULL,
		[Report_Type] [varchar](256) NULL,
		[aggr_type] [varchar](256) NULL,
		[MOS_Num] [float] NULL,
		[MOS_Samples] [float] NULL,
		[1_WB] [float] NULL,
		[2_WB] [float] NULL,
		[3_WB] [float] NULL,
		[4_WB] [float] NULL,
		[5_WB] [float] NULL,
		[6_WB] [float] NULL,
		[7_WB] [float] NULL,
		[8_WB] [float] NULL,
		[MOS ALL Samples WB] [float] NULL,
		[MOS Below 2.5 Samples WB] [float] NULL,
		[MOS Over 3.5 Samples WB] [float] NULL,
		[1_NB] [float] NULL,
		[2_NB] [float] NULL,
		[3_NB] [float] NULL,
		[4_NB] [float] NULL,
		[5_NB] [float] NULL,
		[6_NB] [float] NULL,
		[7_NB] [float] NULL,
		[8_NB] [float] NULL,
		[MOS ALL Samples NB] [float] NULL,
		[MOS Below 2.5 Samples NB] [float] NULL,
		[MOS Over 3.5 Samples NB] [float] NULL,
		[MOS_Samples_Under_2.5] [float] NULL,
		[MOS_NB_Samples_Under_2.5] [float] NULL,
		[Samples_DL+UL] [float] NULL,
		[Samples_DL+UL_NB] [float] NULL,
		[WB AMR Only] [float] NULL,
		[Avg WB AMR Only] [float] NULL,
		[MOS_NB_Num] [float] NULL,
		[MOS_NB_Den] [float] NULL,
		[WB_AMR_Only_Num] [float] NULL,
		[WB_AMR_Only_Den] [float] NULL,
		[MOS_Overall_Samples_Under_2.5] [float] NULL,
		--[Region_Road_VF]	[nvarchar](256)	NULL, 
		--[Region_Road_OSP]	[nvarchar](256)	NUL
		[ASideDevice] [nvarchar](256) NULL,
		[BSideDevice] [nvarchar](256) NULL,
		[SWVersion] [nvarchar](256) NULL
	) ON [PRIMARY]


	CREATE TABLE _RI_Voice_cst(
		[calltype] [nvarchar](256) NULL,
		[codigo_ine] [float] NULL,
		[vf_environment] [nvarchar](255) NULL,
		[mnc] [varchar](2) NULL,
		[meas_round] [varchar](256) NULL,
		[meas_date] [varchar](256) NULL,
		[meas_week] [varchar](256) NULL,
		[meas_Tech] [varchar](256) NOT NULL,
		[info_available] [float] NOT NULL,
		[vf_entity] [varchar](256) NULL,
		[Report_Type] [varchar](256) NULL,
		[aggr_type] [varchar](256) NULL,
		[CST_ALERTING_NUM] [float] NULL,
		[CST_CONNECT_NUM] [float] NULL,
		[CST_MO_AL_samples] [float] NULL,
		[CST_MT_AL_samples] [float] NULL,
		[CST_MO_CO_Samples] [float] NULL,
		[CST_MT_CO_Samples] [float] NULL,
		[CST_MO_AL_NUM] [float] NULL,
		[CST_MT_AL_NUM] [float] NULL,
		[CST_MO_CO_NUM] [float] NULL,
		[CST_MT_CO_NUM] [float] NULL,
		[1_MO_A] [float] NULL,
		[2_MO_A] [float] NULL,
		[3_MO_A] [float] NULL,
		[4_MO_A] [float] NULL,
		[5_MO_A] [float] NULL,
		[6_MO_A] [float] NULL,
		[7_MO_A] [float] NULL,
		[8_MO_A] [float] NULL,
		[9_MO_A] [float] NULL,
		[10_MO_A] [float] NULL,
		[11_MO_A] [float] NULL,
		[12_MO_A] [float] NULL,
		[13_MO_A] [float] NULL,
		[14_MO_A] [float] NULL,
		[15_MO_A] [float] NULL,
		[16_MO_A] [float] NULL,
		[17_MO_A] [float] NULL,
		[18_MO_A] [float] NULL,
		[19_MO_A] [float] NULL,
		[20_MO_A] [float] NULL,
		[21_MO_A] [float] NULL,
		[22_MO_A] [float] NULL,
		[23_MO_A] [float] NULL,
		[24_MO_A] [float] NULL,
		[25_MO_A] [float] NULL,
		[26_MO_A] [float] NULL,
		[27_MO_A] [float] NULL,
		[28_MO_A] [float] NULL,
		[29_MO_A] [float] NULL,
		[30_MO_A] [float] NULL,
		[31_MO_A] [float] NULL,
		[32_MO_A] [float] NULL,
		[33_MO_A] [float] NULL,
		[34_MO_A] [float] NULL,
		[35_MO_A] [float] NULL,
		[36_MO_A] [float] NULL,
		[37_MO_A] [float] NULL,
		[38_MO_A] [float] NULL,
		[39_MO_A] [float] NULL,
		[40_MO_A] [float] NULL,
		[41_MO_A] [float] NULL,

		[1_MT_A] [float] NULL,
		[2_MT_A] [float] NULL,
		[3_MT_A] [float] NULL,
		[4_MT_A] [float] NULL,
		[5_MT_A] [float] NULL,
		[6_MT_A] [float] NULL,
		[7_MT_A] [float] NULL,
		[8_MT_A] [float] NULL,
		[9_MT_A] [float] NULL,
		[10_MT_A] [float] NULL,
		[11_MT_A] [float] NULL,
		[12_MT_A] [float] NULL,
		[13_MT_A] [float] NULL,
		[14_MT_A] [float] NULL,
		[15_MT_A] [float] NULL,
		[16_MT_A] [float] NULL,
		[17_MT_A] [float] NULL,
		[18_MT_A] [float] NULL,
		[19_MT_A] [float] NULL,
		[20_MT_A] [float] NULL,
		[21_MT_A] [float] NULL,
		[22_MT_A] [float] NULL,
		[23_MT_A] [float] NULL,
		[24_MT_A] [float] NULL,
		[25_MT_A] [float] NULL,
		[26_MT_A] [float] NULL,
		[27_MT_A] [float] NULL,
		[28_MT_A] [float] NULL,
		[29_MT_A] [float] NULL,
		[30_MT_A] [float] NULL,
		[31_MT_A] [float] NULL,
		[32_MT_A] [float] NULL,
		[33_MT_A] [float] NULL,
		[34_MT_A] [float] NULL,
		[35_MT_A] [float] NULL,
		[36_MT_A] [float] NULL,
		[37_MT_A] [float] NULL,
		[38_MT_A] [float] NULL,
		[39_MT_A] [float] NULL,
		[40_MT_A] [float] NULL,
		[41_MT_A] [float] NULL,

		[1_MOMT_A] [float] NULL,
		[2_MOMT_A] [float] NULL,
		[3_MOMT_A] [float] NULL,
		[4_MOMT_A] [float] NULL,
		[5_MOMT_A] [float] NULL,
		[6_MOMT_A] [float] NULL,
		[7_MOMT_A] [float] NULL,
		[8_MOMT_A] [float] NULL,
		[9_MOMT_A] [float] NULL,
		[10_MOMT_A] [float] NULL,
		[11_MOMT_A] [float] NULL,
		[12_MOMT_A] [float] NULL,
		[13_MOMT_A] [float] NULL,
		[14_MOMT_A] [float] NULL,
		[15_MOMT_A] [float] NULL,
		[16_MOMT_A] [float] NULL,
		[17_MOMT_A] [float] NULL,
		[18_MOMT_A] [float] NULL,
		[19_MOMT_A] [float] NULL,
		[20_MOMT_A] [float] NULL,
		[21_MOMT_A] [float] NULL,
		[22_MOMT_A] [float] NULL,
		[23_MOMT_A] [float] NULL,
		[24_MOMT_A] [float] NULL,
		[25_MOMT_A] [float] NULL,
		[26_MOMT_A] [float] NULL,
		[27_MOMT_A] [float] NULL,
		[28_MOMT_A] [float] NULL,
		[29_MOMT_A] [float] NULL,
		[30_MOMT_A] [float] NULL,
		[31_MOMT_A] [float] NULL,
		[32_MOMT_A] [float] NULL,
		[33_MOMT_A] [float] NULL,
		[34_MOMT_A] [float] NULL,
		[35_MOMT_A] [float] NULL,
		[36_MOMT_A] [float] NULL,
		[37_MOMT_A] [float] NULL,
		[38_MOMT_A] [float] NULL,
		[39_MOMT_A] [float] NULL,
		[40_MOMT_A] [float] NULL,
		[41_MOMT_A] [float] NULL,
		
		[1_MO_C] [float] NULL,
		[2_MO_C] [float] NULL,
		[3_MO_C] [float] NULL,
		[4_MO_C] [float] NULL,
		[5_MO_C] [float] NULL,
		[6_MO_C] [float] NULL,
		[7_MO_C] [float] NULL,
		[8_MO_C] [float] NULL,
		[9_MO_C] [float] NULL,
		[10_MO_C] [float] NULL,
		[11_MO_C] [float] NULL,
		[12_MO_C] [float] NULL,
		[13_MO_C] [float] NULL,
		[14_MO_C] [float] NULL,
		[15_MO_C] [float] NULL,
		[16_MO_C] [float] NULL,
		[17_MO_C] [float] NULL,
		[18_MO_C] [float] NULL,
		[19_MO_C] [float] NULL,
		[20_MO_C] [float] NULL,
		[21_MO_C] [float] NULL,
		[22_MO_C] [float] NULL,
		[23_MO_C] [float] NULL,
		[24_MO_C] [float] NULL,
		[25_MO_C] [float] NULL,
		[26_MO_C] [float] NULL,
		[27_MO_C] [float] NULL,
		[28_MO_C] [float] NULL,
		[29_MO_C] [float] NULL,
		[30_MO_C] [float] NULL,
		[31_MO_C] [float] NULL,
		[32_MO_C] [float] NULL,
		[33_MO_C] [float] NULL,
		[34_MO_C] [float] NULL,
		[35_MO_C] [float] NULL,
		[36_MO_C] [float] NULL,
		[37_MO_C] [float] NULL,
		[38_MO_C] [float] NULL,
		[39_MO_C] [float] NULL,
		[40_MO_C] [float] NULL,
		[41_MO_C] [float] NULL,

		[1_MT_C] [float] NULL,
		[2_MT_C] [float] NULL,
		[3_MT_C] [float] NULL,
		[4_MT_C] [float] NULL,
		[5_MT_C] [float] NULL,
		[6_MT_C] [float] NULL,
		[7_MT_C] [float] NULL,
		[8_MT_C] [float] NULL,
		[9_MT_C] [float] NULL,
		[10_MT_C] [float] NULL,
		[11_MT_C] [float] NULL,
		[12_MT_C] [float] NULL,
		[13_MT_C] [float] NULL,
		[14_MT_C] [float] NULL,
		[15_MT_C] [float] NULL,
		[16_MT_C] [float] NULL,
		[17_MT_C] [float] NULL,
		[18_MT_C] [float] NULL,
		[19_MT_C] [float] NULL,
		[20_MT_C] [float] NULL,
		[21_MT_C] [float] NULL,
		[22_MT_C] [float] NULL,
		[23_MT_C] [float] NULL,
		[24_MT_C] [float] NULL,
		[25_MT_C] [float] NULL,
		[26_MT_C] [float] NULL,
		[27_MT_C] [float] NULL,
		[28_MT_C] [float] NULL,
		[29_MT_C] [float] NULL,
		[30_MT_C] [float] NULL,
		[31_MT_C] [float] NULL,
		[32_MT_C] [float] NULL,
		[33_MT_C] [float] NULL,
		[34_MT_C] [float] NULL,
		[35_MT_C] [float] NULL,
		[36_MT_C] [float] NULL,
		[37_MT_C] [float] NULL,
		[38_MT_C] [float] NULL,
		[39_MT_C] [float] NULL,
		[40_MT_C] [float] NULL,
		[41_MT_C] [float] NULL,

		[1_MOMT_C] [float] NULL,
		[2_MOMT_C] [float] NULL,
		[3_MOMT_C] [float] NULL,
		[4_MOMT_C] [float] NULL,
		[5_MOMT_C] [float] NULL,
		[6_MOMT_C] [float] NULL,
		[7_MOMT_C] [float] NULL,
		[8_MOMT_C] [float] NULL,
		[9_MOMT_C] [float] NULL,
		[10_MOMT_C] [float] NULL,
		[11_MOMT_C] [float] NULL,
		[12_MOMT_C] [float] NULL,
		[13_MOMT_C] [float] NULL,
		[14_MOMT_C] [float] NULL,
		[15_MOMT_C] [float] NULL,
		[16_MOMT_C] [float] NULL,
		[17_MOMT_C] [float] NULL,
		[18_MOMT_C] [float] NULL,
		[19_MOMT_C] [float] NULL,
		[20_MOMT_C] [float] NULL,
		[21_MOMT_C] [float] NULL,
		[22_MOMT_C] [float] NULL,
		[23_MOMT_C] [float] NULL,
		[24_MOMT_C] [float] NULL,
		[25_MOMT_C] [float] NULL,
		[26_MOMT_C] [float] NULL,
		[27_MOMT_C] [float] NULL,
		[28_MOMT_C] [float] NULL,
		[29_MOMT_C] [float] NULL,
		[30_MOMT_C] [float] NULL,
		[31_MOMT_C] [float] NULL,
		[32_MOMT_C] [float] NULL,
		[33_MOMT_C] [float] NULL,
		[34_MOMT_C] [float] NULL,
		[35_MOMT_C] [float] NULL,
		[36_MOMT_C] [float] NULL,
		[37_MOMT_C] [float] NULL,
		[38_MOMT_C] [float] NULL,
		[39_MOMT_C] [float] NULL,
		[40_MOMT_C] [float] NULL,
		[41_MOMT_C] [float] NULL,
		--[Region_Road_VF]	[nvarchar](256)	NULL, 
		--[Region_Road_OSP]	[nvarchar](256)	NUL
		[ASideDevice] [nvarchar](256) NULL,
		[BSideDevice] [nvarchar](256) NULL,
		[SWVersion] [nvarchar](256) NULL
	) ON [PRIMARY]


	CREATE TABLE _RI_Voice_cst_csfb(
		[calltype] [nvarchar](256) NULL,
		[codigo_ine] [float] NULL,
		[vf_environment] [nvarchar](256) NULL,
		[mnc] [varchar](2) NULL,
		[meas_round] [varchar](256) NULL,
		[meas_date] [varchar](256) NULL,
		[meas_week] [varchar](256) NULL,
		[meas_Tech] [varchar](256) NOT NULL,
		[info_available] [float] NOT NULL,
		[vf_entity] [varchar](256) NULL,
		[Report_Type] [varchar](256) NULL,
		[aggr_type] [varchar](256) NULL,
		[CST_ALERTING_UMTS_samples] [float] NULL,
		[CST_ALERTING_UMTS900_samples] [float] NULL,
		[CST_ALERTING_UMTS2100_samples] [float] NULL,
		[CST_ALERTING_GSM_samples] [float] NULL,
		[CST_ALERTING_GSM900_samples] [float] NULL,
		[CST_ALERTING_GSM1800_samples] [float] NULL,
		[CST_ALERTING_UMTS_NUM] [float] NULL,
		[CST_ALERTING_UMTS900_NUM] [float] NULL,
		[CST_ALERTING_UMTS2100_NUM] [float] NULL,
		[CST_ALERTING_GSM_NUM] [float] NULL,
		[CST_ALERTING_GSM900_NUM] [float] NULL,
		[CST_ALERTING_GSM1800_NUM] [float] NULL,
		[CST_CONNECT_UMTS_samples] [float] NULL,
		[CST_CONNECT_UMTS900_samples] [float] NULL,
		[CST_CONNECT_UMTS2100_samples] [float] NULL,
		[CST_CONNECT_GSM_samples] [float] NULL,
		[CST_CONNECT_GSM900_samples] [float] NULL,
		[CST_CONNECT_GSM1800_samples] [float] NULL,
		[CST_CONNECT_UMTS_NUM] [float] NULL,
		[CST_CONNECT_UMTS900_NUM] [float] NULL,
		[CST_CONNECT_UMTS2100_NUM] [float] NULL,
		[CST_CONNECT_GSM_NUM] [float] NULL,
		[CST_CONNECT_GSM900_NUM] [float] NULL,
		[CST_CONNECT_GSM1800_NUM] [float] NULL,
		[CSFB_duration_samples] [float] NULL,
		[CSFB_duration_num] [float] NULL,
		[MOS_2G_Num] [float] NULL,
		[MOS_2G_Samples] [float] NULL,
		[MOS_3G_Num] [float] NULL,
		[MOS_3G_Samples] [float] NULL,
		[MOS_GSM_Num] [float] NULL,
		[MOS_GSM_Samples] [float] NULL,
		[MOS_DCS_Num] [float] NULL,
		[MOS_DCS_Samples] [float] NULL,
		[MOS_UMTS900_Num] [float] NULL,
		[MOS_UMTS900_Samples] [float] NULL,
		[MOS_UMTS2100_Num] [float] NULL,
		[MOS_UMTS2100_Samples] [float] NULL,
		[Call_duration_UMTS2100] [float] NULL,
		[Call_duration_UMTS900] [float] NULL,
		[Call_duration_GSM] [float] NULL,
		[Call_duration_DCS] [float] NULL,
		[Call_Duration_4G] [float] NULL,
		[Call_Duration_LTE2600] [float] NULL,
		[Call_Duration_LTE2100] [float] NULL,
		[Call_Duration_LTE1800] [float] NULL,
		[Call_Duration_LTE800] [float] NULL,
		--[Region_Road_VF]	[nvarchar](256)	NULL, 
		--[Region_Road_OSP]	[nvarchar](256)	NUL
		[ASideDevice] [nvarchar](256) NULL,
		[BSideDevice] [nvarchar](256) NULL,
		[SWVersion] [nvarchar](256) NULL
	) ON [PRIMARY]


	------------------------------------------------------------------------------
	-- 1. Llamadas 3G, 4G y Road 
	------------------------------------------------------------------------------
	print ' 1.1 Llamadas 3G, 4G y Road'
	-----------
	insert into _RI_Voice_c
	select 
		t.calltype as Calltype, 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week, 
		'3G' as meas_Tech, 1 as info_available, entidad as vf_entity, Report_Type, aggr_type,

		-- General:
		sum(mo_succeeded+mo_blocks+mo_drops) as MOC_Calls,
		sum(mt_succeeded+mt_blocks+mt_drops) as MTC_Calls,
		sum(mo_blocks) as MOC_Blocks,
		sum(mt_blocks) as MTC_Blocks,
		sum(mo_drops) as MOC_Drops,
		sum(mt_drops) as MTC_Drops,
		sum(mo_succeeded+mo_blocks+mo_drops+mt_succeeded+mt_blocks+mt_drops) as Calls,
		sum(mo_blocks+mt_blocks) as Blocks,
		sum(mo_drops+mt_drops) as Drops,
		sum([CR_Affected_Calls]) as CR_Affected_Calls,

		sum(duration_3g) as Call_duration_3G,
		sum(duration_2g) as Call_duration_2G,
		sum(duration_3g+duration_2g) as Call_duration_tech_samples,
		sum(gsm_calls_after_csfb_comp) as CSFB_to_GSM_samples,
		sum(UMTS_Calls_after_csfb_comp) as CSFB_to_UMTS_samples,
		sum(gsm_calls_after_csfb_comp+UMTS_Calls_after_csfb_comp) as CSFB_samples,

		sum(case when Codec_Registers is null then AMR_FR else AMR_FR_Count end) as AMR_FR_samples,
		sum(case when Codec_Registers is null then AMR_HR else AMR_HR_Count end) as AMR_HR_samples,
		sum(case when Codec_Registers is null then AMR_WB else AMR_WB_Count end) as AMR_WB_samples,
		sum(case when Codec_Registers is null then FR else FR_Count end) as FR_samples,
		sum(case when Codec_Registers is null then EFR else EFR_Count end) as EFR_samples,
		sum(case when Codec_Registers is null then HR else HR_Count end) as HR_samples,
		sum(case when Codec_Registers is null then AMR_FR+AMR_HR+AMR_WB+fr+EFR +HR else Codec_Registers end) as codec_samples,
	
		-------------------------------------
		sum([SQNS_NB]) as [NUMBERS OF CALLS Non Sustainability (NB)],
		sum([SQNS_WB]) as [NUMBERS OF CALLS Non Sustainability (WB)],
		sum(Started_Ended_2G_Comp) as Calls_Started_2G_WO_Fails,
		sum(Started_Ended_3G_Comp) as Calls_Started_3G_WO_Fails,
		sum(started_4G_comp) as Calls_Started_4G_WO_Fails,
		sum(calls_mixed_comp) as Calls_Mixed,

		-------------------------------------
		sum(0) as VOLTE_SpeechDelay_Num,		-- en el DASH se reportan, pero no tienen sentido como tal y nunca se ha agregado anteriormente, asi que se deja a nulo
		sum(0) as VOLTE_SpeechDelay_Den,
		sum(0) as VOLTE_Calls_Started_Ended_VOLTE,
		sum(0) as VOLTE_Calls_withSRVCC,
		sum(0) as VOLTE_Calls_is_VOLTE,

		-------------------------------------
		--case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then t.Region_VF else null end as Region_Road_VF,
		--case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then t.Region_OSP else null end as Region_Road_OSP,
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]

	from aggrvoice3g.[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas] t, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,
		mnc, meas_round, Date_Reporting, Week_Reporting, entidad, Report_Type, aggr_type, t.calltype, t.[ASideDevice], t.[BSideDevice], t.[SWVersion]
		--,
		--case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then t.Region_VF else null end,
		--case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then t.Region_OSP else null end

	-----------
	-- 4G:
	insert into _RI_Voice_c
	select 
		t.calltype as Calltype, 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week, 
		'4G' as meas_Tech, 1 as info_available, entidad as vf_entity, Report_Type, aggr_type,
	
		-- General:
		sum(mo_succeeded+mo_blocks+mo_drops) as MOC_Calls,
		sum(mt_succeeded+mt_blocks+mt_drops) as MTC_Calls,
		sum(mo_blocks) as MOC_Blocks,
		sum(mt_blocks) as MTC_Blocks,
		sum(mo_drops) as MOC_Drops,
		sum(mt_drops) as MTC_Drops,
		sum(mo_succeeded+mo_blocks+mo_drops+mt_succeeded+mt_blocks+mt_drops) as Calls,
		sum(mo_blocks+mt_blocks) as Blocks,
		sum(mo_drops+mt_drops) as Drops,
		sum([CR_Affected_Calls]) as CR_Affected_Calls,

		sum(duration_3g) as Call_duration_3G,
		sum(duration_2g) as Call_duration_2G,
		sum(duration_3g+duration_2g) as Call_duration_tech_samples,
		sum(gsm_calls_after_csfb_comp) as CSFB_to_GSM_samples,
		sum(UMTS_Calls_after_csfb_comp) as CSFB_to_UMTS_samples,
		sum(gsm_calls_after_csfb_comp+UMTS_Calls_after_csfb_comp) as CSFB_samples,

		sum(case when Codec_Registers is null then AMR_FR else AMR_FR_Count end) as AMR_FR_samples,
		sum(case when Codec_Registers is null then AMR_HR else AMR_HR_Count end) as AMR_HR_samples,
		sum(case when Codec_Registers is null then AMR_WB else AMR_WB_Count end) as AMR_WB_samples,
		sum(case when Codec_Registers is null then FR else FR_Count end) as FR_samples,
		sum(case when Codec_Registers is null then EFR else EFR_Count end) as EFR_samples,
		sum(case when Codec_Registers is null then HR else HR_Count end) as HR_samples,
		sum(case when Codec_Registers is null then AMR_FR+AMR_HR+AMR_WB+fr+EFR +HR else Codec_Registers end) as codec_samples,

		-------------------------------------
		sum([SQNS_NB]) as [NUMBERS OF CALLS Non Sustainability (NB)],
		sum([SQNS_WB]) as [NUMBERS OF CALLS Non Sustainability (WB)],
		sum(Started_Ended_2G_Comp) as Calls_Started_2G_WO_Fails,
		sum(Started_Ended_3G_Comp) as Calls_Started_3G_WO_Fails,
		sum(started_4G_comp) as Calls_Started_4G_WO_Fails,
		sum(calls_mixed_comp) as Calls_Mixed,

		-------------------------------------
		sum(0) as VOLTE_SpeechDelay_Num,		-- en el DASH se reportan, pero no tienen sentido como tal y nunca se ha agregado anteriormente, asi que se deja a nulo
		sum(0) as VOLTE_SpeechDelay_Den,
		sum(0) as VOLTE_Calls_Started_Ended_VOLTE,
		sum(0) as VOLTE_Calls_withSRVCC,
		sum(0) as VOLTE_Calls_is_VOLTE,

		-------------------------------------
		--case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_VF end as Region_Road_VF,
		--case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_OSP end as Region_Road_OSP,
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]

	from aggrvoice4g.[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas] t, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end ,mnc,meas_round,Date_Reporting,Week_Reporting,entidad, Report_Type, aggr_type
		,t.calltype, t.[ASideDevice], t.[BSideDevice], t.[SWVersion]
		--,
		--case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_VF end,
		--case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_OSP end


	-----------
	-- Road 4G:
	insert into _RI_Voice_c
	select  
		t.Calltype as Calltype,
		p.codigo_ine, 'Roads' vf_environment,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week, 
		'Road 4G' as meas_Tech, 1 as info_available, entidad as vf_entity, Report_Type, aggr_type,

		-- General:
		sum(mo_succeeded+mo_blocks+mo_drops) as MOC_Calls,
		sum(mt_succeeded+mt_blocks+mt_drops) as MTC_Calls,
		sum(mo_blocks) as MOC_Blocks,
		sum(mt_blocks) as MTC_Blocks,
		sum(mo_drops) as MOC_Drops,
		sum(mt_drops) as MTC_Drops,
		sum(mo_succeeded+mo_blocks+mo_drops+mt_succeeded+mt_blocks+mt_drops) as Calls,
		sum(mo_blocks+mt_blocks) as Blocks,
		sum(mo_drops+	mt_drops) as Drops,
		sum([CR_Affected_Calls]) as CR_Affected_Calls,

		sum(duration_3g) as Call_duration_3G,
		sum(duration_2g) as Call_duration_2G,
		sum(duration_3g+duration_2g) as Call_duration_tech_samples,
		sum(gsm_calls_after_csfb_comp) as CSFB_to_GSM_samples,
		sum(UMTS_Calls_after_csfb_comp) as CSFB_to_UMTS_samples,
		sum(gsm_calls_after_csfb_comp+UMTS_Calls_after_csfb_comp) as CSFB_samples,

		sum(case when Codec_Registers is null then AMR_FR else AMR_FR_Count end) as AMR_FR_samples,
		sum(case when Codec_Registers is null then AMR_HR else AMR_HR_Count end) as AMR_HR_samples,
		sum(case when Codec_Registers is null then AMR_WB else AMR_WB_Count end) as AMR_WB_samples,
		sum(case when Codec_Registers is null then FR else FR_Count end) as FR_samples,
		sum(case when Codec_Registers is null then EFR else EFR_Count end) as EFR_samples,
		sum(case when Codec_Registers is null then HR else HR_Count end) as HR_samples,
		sum(case when Codec_Registers is null then AMR_FR+AMR_HR+AMR_WB+fr+EFR +HR else Codec_Registers end) as codec_samples,

		-------------------------------------
		sum([SQNS_NB]) as [NUMBERS OF CALLS Non Sustainability (NB)],
		sum([SQNS_WB]) as [NUMBERS OF CALLS Non Sustainability (WB)],
		sum(Started_Ended_2G_Comp) as Calls_Started_2G_WO_Fails,
		sum(Started_Ended_3G_Comp) as Calls_Started_3G_WO_Fails,
		sum(started_4G_comp) as Calls_Started_4G_WO_Fails,
		sum(calls_mixed_comp) as Calls_Mixed,

		-------------------------------------
		sum(0) as VOLTE_SpeechDelay_Num,		-- en el DASH se reportan, pero no tienen sentido como tal y nunca se ha agregado anteriormente, asi que se deja a nulo
		sum(0) as VOLTE_SpeechDelay_Den,
		sum(0) as VOLTE_Calls_Started_Ended_VOLTE,
		sum(0) as VOLTE_Calls_withSRVCC,
		sum(0) as VOLTE_Calls_is_VOLTE,

		-------------------------------------
		--t.Region_VF as Region_Road_VF, t.Region_OSP as Region_Road_OSP, 
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]

	from [AGGRVoice4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas] t, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,mnc,meas_round,Date_Reporting,Week_Reporting,entidad, Report_Type, aggr_type, t.Region_VF, t.Region_OSP, t.calltype, 
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]--, t.Region_VF, t.Region_OSP

	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 1.1 Llamadas 3G, 4G y Road', getdate()


	----------------------------------------------------------------------------------------------------------
	/*		1.2. Cruzamos con la tabla de 4G para saber qué entidades tenemos que reportar para 4GOnly. 
				 Si una medida no ha cursado nada en esta tecnología saldría vacía.						   */
	---------------------------------------------------------------------------------------------------------- 
	print '1.2 Llamadas 4GOnly y 4GOnly Road'
	-----------
	-- 4GOnly:
	insert into _RI_Voice_c
	select
		t.calltype as Calltype,
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,t.mnc,t.meas_round,t.Date_Reporting as meas_date,t.Week_Reporting as meas_week,
		'4GOnly' as meas_Tech, 	1 as info_available, t.entidad as vf_entity, t.Report_Type, t.aggr_type,
	
		sum(O4G.mo_succeeded+O4G.mo_blocks+O4G.mo_drops) as MOC_Calls,
		sum(O4G.mt_succeeded+O4G.mt_blocks+O4G.mt_drops) as MTC_Calls,
		sum(O4G.mo_blocks) as MOC_Blocks,
		sum(O4G.mt_blocks) as MTC_Blocks,
		sum(O4G.mo_drops) as MOC_Drops,
		sum(O4G.mt_drops) as MTC_Drops,
		sum(O4G.mo_succeeded+O4G.mo_blocks+O4G.mo_drops+O4G.mt_succeeded+O4G.mt_blocks+O4G.mt_drops) as Calls,
		sum(O4G.mo_blocks+O4G.mt_blocks) as Blocks,
		sum(O4G.mo_drops+O4G.mt_drops) as Drops,
		sum(O4G.[CR_Affected_Calls]) as CR_Affected_Calls,

		sum(O4G.duration_3g) as Call_duration_3G,
		sum(O4G.duration_2g) as Call_duration_2G,
		sum(O4G.duration_3g+O4G.duration_2g) as Call_duration_tech_samples,
		sum(O4G.gsm_calls_after_csfb_comp) as CSFB_to_GSM_samples,
		sum(O4G.UMTS_Calls_after_csfb_comp) as CSFB_to_UMTS_samples,
		sum(O4G.gsm_calls_after_csfb_comp+O4G.UMTS_Calls_after_csfb_comp) as CSFB_samples,

		sum(case when O4G.Codec_Registers is null then O4G.AMR_FR else O4G.AMR_FR_Count end) as AMR_FR_samples,
		sum(case when O4G.Codec_Registers is null then O4G.AMR_HR else O4G.AMR_HR_Count end) as AMR_HR_samples,
		sum(case when O4G.Codec_Registers is null then O4G.AMR_WB else O4G.AMR_WB_Count end) as AMR_WB_samples,
		sum(case when O4G.Codec_Registers is null then O4G.FR else O4G.FR_Count end) as FR_samples,
		sum(case when O4G.Codec_Registers is null then O4G.EFR else O4G.EFR_Count end) as EFR_samples,
		sum(case when O4G.Codec_Registers is null then O4G.HR else O4G.HR_Count end) as HR_samples,
		sum(case when O4G.Codec_Registers is null then O4G.AMR_FR+O4G.AMR_HR+O4G.AMR_WB+O4G.FR+O4G.EFR+O4G.HR else O4G.Codec_Registers end) as codec_samples,
		
		-------------------------------------
		sum(O4G.[SQNS_NB]) as [NUMBERS OF CALLS Non Sustainability (NB)],
		sum(O4G.[SQNS_WB]) as [NUMBERS OF CALLS Non Sustainability (WB)],
		sum(O4G.Started_Ended_2G_Comp) as Calls_Started_2G_WO_Fails,
		sum(O4G.Started_Ended_3G_Comp) as Calls_Started_3G_WO_Fails,
		sum(O4G.started_4G_comp) as Calls_Started_4G_WO_Fails,
		sum(O4G.calls_mixed_comp) as Calls_Mixed,

		-------------------------------------
		sum(0) as VOLTE_SpeechDelay_Num,
		sum(0) as VOLTE_SpeechDelay_Den,
		sum(0) as VOLTE_Calls_Started_Ended_VOLTE,
		sum(0) as VOLTE_Calls_withSRVCC,
		sum(0) as VOLTE_Calls_is_VOLTE,

		-------------------------------------
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_VF end as Region_Road_VF,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_OSP end as Region_Road_OSP,  

		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]

	from aggrvoice4g.[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas] t
			left outer join aggrvoice4g.[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas_4G] O4G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(O4G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=O4G.mnc and t.Date_Reporting=O4G.Date_Reporting and t.entidad=O4G.entidad and t.Aggr_Type=O4G.Aggr_Type and t.Report_Type=O4G.Report_Type and t.meas_round=O4G.meas_round)
		,[AGRIDS].[dbo].vlcc_parcelas_osp p

	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end ,t.mnc,t.meas_round,t.Date_Reporting,t.Week_Reporting,t.entidad, t.Report_Type, t.aggr_type
		,t.calltype, t.[ASideDevice], t.[BSideDevice], t.[SWVersion]--,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_VF end,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_OSP end


	---------
	-- Road 4GOnly:
	insert into _RI_Voice_c
	select  
		t.Calltype as Calltype,
		p.codigo_ine, 'Roads' vf_environment,t.mnc,t.meas_round,t.Date_Reporting as meas_date,t.Week_Reporting as meas_week, 
		'Road 4GOnly' as meas_Tech, 1 as info_available, t.entidad as vf_entity, t.Report_Type, t.aggr_type,
	
		sum(O4G.mo_succeeded+O4G.mo_blocks+O4G.mo_drops) as MOC_Calls,
		sum(O4G.mt_succeeded+O4G.mt_blocks+O4G.mt_drops) as MTC_Calls,
		sum(O4G.mo_blocks) as MOC_Blocks,
		sum(O4G.mt_blocks) as MTC_Blocks,
		sum(O4G.mo_drops) as MOC_Drops,
		sum(O4G.mt_drops) as MTC_Drops,
		sum(O4G.mo_succeeded+O4G.mo_blocks+O4G.mo_drops+O4G.mt_succeeded+O4G.mt_blocks+O4G.mt_drops) as Calls,
		sum(O4G.mo_blocks+O4G.mt_blocks) as Blocks,
		sum(O4G.mo_drops+	O4G.mt_drops) as Drops,
		sum(O4G.[CR_Affected_Calls]) as CR_Affected_Calls,

		sum(O4G.duration_3g) as Call_duration_3G,
		sum(O4G.duration_2g) as Call_duration_2G,
		sum(O4G.duration_3g+O4G.duration_2g) as Call_duration_tech_samples,
		sum(O4G.gsm_calls_after_csfb_comp) as CSFB_to_GSM_samples,
		sum(O4G.UMTS_Calls_after_csfb_comp) as CSFB_to_UMTS_samples,
		sum(O4G.gsm_calls_after_csfb_comp+O4G.UMTS_Calls_after_csfb_comp) as CSFB_samples,

		sum(case when O4G.Codec_Registers is null then O4G.AMR_FR else O4G.AMR_FR_Count end) as AMR_FR_samples,
		sum(case when O4G.Codec_Registers is null then O4G.AMR_HR else O4G.AMR_HR_Count end) as AMR_HR_samples,
		sum(case when O4G.Codec_Registers is null then O4G.AMR_WB else O4G.AMR_WB_Count end) as AMR_WB_samples,
		sum(case when O4G.Codec_Registers is null then O4G.FR else O4G.FR_Count end) as FR_samples,
		sum(case when O4G.Codec_Registers is null then O4G.EFR else O4G.EFR_Count end) as EFR_samples,
		sum(case when O4G.Codec_Registers is null then O4G.HR else O4G.HR_Count end) as HR_samples,
		sum(case when O4G.Codec_Registers is null then O4G.AMR_FR+O4G.AMR_HR+O4G.AMR_WB+O4G.FR+O4G.EFR +O4G.HR else O4G.Codec_Registers end) as codec_samples,

		-------------------------------------
		sum(O4G.[SQNS_NB]) as [NUMBERS OF CALLS Non Sustainability (NB)],
		sum(O4G.[SQNS_WB]) as [NUMBERS OF CALLS Non Sustainability (WB)],
		sum(O4G.Started_Ended_2G_Comp) as Calls_Started_2G_WO_Fails,
		sum(O4G.Started_Ended_3G_Comp) as Calls_Started_3G_WO_Fails,
		sum(O4G.started_4G_comp) as Calls_Started_4G_WO_Fails,
		sum(O4G.calls_mixed_comp) as Calls_Mixed,

		-------------------------------------
		sum(0) as VOLTE_SpeechDelay_Num,		-- en el DASH se reportan, pero no tienen sentido como tal y nunca se ha agregado anteriormente, asi que se deja a nulo
		sum(0) as VOLTE_SpeechDelay_Den,
		sum(0) as VOLTE_Calls_Started_Ended_VOLTE,
		sum(0) as VOLTE_Calls_withSRVCC,
		sum(0) as VOLTE_Calls_is_VOLTE,

		-------------------------------------
		--t.Region_VF as Region_Road_VF, t.Region_OSP as Region_Road_OSP,   
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]

	from [AGGRVoice4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas] t
			left outer join [AGGRVoice4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas_4G] O4G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(O4G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=O4G.mnc and t.Date_Reporting=O4G.Date_Reporting and t.entidad=O4G.entidad and t.Aggr_Type=O4G.Aggr_Type and t.Report_Type=O4G.Report_Type and t.meas_round=O4G.meas_round)
		,[AGRIDS].[dbo].vlcc_parcelas_osp p

	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,t.mnc,t.meas_round,t.Date_Reporting,t.Week_Reporting,t.entidad,t.Report_Type,t.aggr_type, t.calltype, 
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]--, t.Region_VF, t.Region_OSP

	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 1.2 Llamadas 4GOnly y 4GOnly Road', getdate()


	--------------------------------------------------------------------------------------
	/* 1.3 Se añade info VOLTE - ALL, 4G, RealVOLTE, 3G									*/
	--------------------------------------------------------------------------------------
	print '1.3 Llamadas VOLTE - ALL, 4G, RealVOLTE, 3G'
	-----------
	-- VOLTE ALL:
	insert into _RI_Voice_c
	select  
		volte.calltype as Calltype,
		p.codigo_ine, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment, volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week,
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE ALL Road' 
			else 'VOLTE ALL' end as meas_Tech, 	1 as info_available, volte.entidad as vf_entity, volte.Report_Type, volte.aggr_type,
	
		sum(volte.mo_succeeded+volte.mo_blocks+volte.mo_drops) as MOC_Calls,
		sum(volte.mt_succeeded+volte.mt_blocks+volte.mt_drops) as MTC_Calls,
		sum(volte.mo_blocks) as MOC_Blocks,
		sum(volte.mt_blocks) as MTC_Blocks,
		sum(volte.mo_drops) as MOC_Drops,
		sum(volte.mt_drops) as MTC_Drops,
		sum(volte.mo_succeeded+volte.mo_blocks+volte.mo_drops+volte.mt_succeeded+volte.mt_blocks+volte.mt_drops) as Calls,
		sum(volte.mo_blocks+volte.mt_blocks) as Blocks,
		sum(volte.mo_drops+volte.mt_drops) as Drops,
		sum(volte.[CR_Affected_Calls]) as CR_Affected_Calls,

		sum(volte.duration_3g) as Call_duration_3G,
		sum(volte.duration_2g) as Call_duration_2G,
		sum(volte.duration_3g+volte.duration_2g) as Call_duration_tech_samples,
		sum(volte.gsm_calls_after_csfb_comp) as CSFB_to_GSM_samples,
		sum(volte.UMTS_Calls_after_csfb_comp) as CSFB_to_UMTS_samples,
		sum(volte.gsm_calls_after_csfb_comp+volte.UMTS_Calls_after_csfb_comp) as CSFB_samples,

		sum(case when volte.Codec_Registers is null then volte.AMR_FR else volte.AMR_FR_Count end) as AMR_FR_samples,
		sum(case when volte.Codec_Registers is null then volte.AMR_HR else volte.AMR_HR_Count end) as AMR_HR_samples,
		sum(case when volte.Codec_Registers is null then volte.AMR_WB else volte.AMR_WB_Count end) as AMR_WB_samples,
		sum(case when volte.Codec_Registers is null then volte.FR else volte.FR_Count end) as FR_samples,
		sum(case when volte.Codec_Registers is null then volte.EFR else volte.EFR_Count end) as EFR_samples,
		sum(case when volte.Codec_Registers is null then volte.HR else volte.HR_Count end) as HR_samples,
		sum(case when volte.Codec_Registers is null then volte.AMR_FR+volte.AMR_HR+volte.AMR_WB+volte.FR+volte.EFR+volte.HR else volte.Codec_Registers end) as codec_samples,
		
		-------------------------------------
		sum(volte.[SQNS_NB]) as [NUMBERS OF CALLS Non Sustainability (NB)],
		sum(volte.[SQNS_WB]) as [NUMBERS OF CALLS Non Sustainability (WB)],
		sum(volte.Started_Ended_2G_Comp) as Calls_Started_2G_WO_Fails,
		sum(volte.Started_Ended_3G_Comp) as Calls_Started_3G_WO_Fails,
		sum(volte.started_4G_comp) as Calls_Started_4G_WO_Fails,
		sum(volte.calls_mixed_comp) as Calls_Mixed,

		-------------------------------------
		sum(vv.VOLTE_Speech_Delay*vv.Count_Speech_Delay) as VOLTE_SpeechDelay_Num,
		sum(vv.Count_Speech_Delay) as VOLTE_SpeechDelay_Den,
		sum(vv.Started_VOLTE) as VOLTE_Calls_Started_Ended_VOLTE,
		sum(vv.SRVCC) as VOLTE_Calls_withSRVCC,
		sum(vv.is_VOLTE) as VOLTE_Calls_is_VOLTE,

		-------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP, 		 
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	from AGGRVOLTE.[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas] volte
			LEFT OUTER JOIN AGGRvolte.[dbo].[lcc_aggr_sp_MDD_Voice_VOLTE] vv on (isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')=isnull(vv.parcel,'0.00000 Long, 0.00000 Lat') and volte.mnc=vv.mnc and volte.Date_Reporting=vv.Date_Reporting and volte.entidad=vv.entidad and volte.Aggr_Type=vv.Aggr_Type and volte.Report_Type=vv.Report_Type and volte.meas_round=vv.meas_round)
		, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, 	
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		else p.vf_environment end, volte.mnc,volte.meas_round,volte.Date_Reporting,volte.Week_Reporting,
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE ALL Road' else 'VOLTE ALL' end, volte.entidad, volte.Report_Type, volte.aggr_type,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end,
		volte.calltype, volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	---------
	-- VOLTE 4G:
	insert into _RI_Voice_c
	select  
		volte.calltype as Calltype,
		p.codigo_ine, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment, volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week,
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 4G Road' 
			else 'VOLTE 4G' end as meas_Tech, 1 as info_available, volte.entidad as vf_entity, volte.Report_Type, volte.aggr_type,
	
		sum(volte4G.mo_succeeded+volte4G.mo_blocks+volte4G.mo_drops) as MOC_Calls,
		sum(volte4G.mt_succeeded+volte4G.mt_blocks+volte4G.mt_drops) as MTC_Calls,
		sum(volte4G.mo_blocks) as MOC_Blocks,
		sum(volte4G.mt_blocks) as MTC_Blocks,
		sum(volte4G.mo_drops) as MOC_Drops,
		sum(volte4G.mt_drops) as MTC_Drops,
		sum(volte4G.mo_succeeded+volte4G.mo_blocks+volte4G.mo_drops+volte4G.mt_succeeded+volte4G.mt_blocks+volte4G.mt_drops) as Calls,
		sum(volte4G.mo_blocks+volte4G.mt_blocks) as Blocks,
		sum(volte4G.mo_drops+volte4G.mt_drops) as Drops,
		sum(volte4G.[CR_Affected_Calls]) as CR_Affected_Calls,

		sum(volte4G.duration_3g) as Call_duration_3G,
		sum(volte4G.duration_2g) as Call_duration_2G,
		sum(volte4G.duration_3g+volte4G.duration_2g) as Call_duration_tech_samples,
		sum(volte4G.gsm_calls_after_csfb_comp) as CSFB_to_GSM_samples,
		sum(volte4G.UMTS_Calls_after_csfb_comp) as CSFB_to_UMTS_samples,
		sum(volte4G.gsm_calls_after_csfb_comp+volte4G.UMTS_Calls_after_csfb_comp) as CSFB_samples,

		sum(case when volte4G.Codec_Registers is null then volte4G.AMR_FR else volte4G.AMR_FR_Count end) as AMR_FR_samples,
		sum(case when volte4G.Codec_Registers is null then volte4G.AMR_HR else volte4G.AMR_HR_Count end) as AMR_HR_samples,
		sum(case when volte4G.Codec_Registers is null then volte4G.AMR_WB else volte4G.AMR_WB_Count end) as AMR_WB_samples,
		sum(case when volte4G.Codec_Registers is null then volte4G.FR else volte4G.FR_Count end) as FR_samples,
		sum(case when volte4G.Codec_Registers is null then volte4G.EFR else volte4G.EFR_Count end) as EFR_samples,
		sum(case when volte4G.Codec_Registers is null then volte4G.HR else volte4G.HR_Count end) as HR_samples,
		sum(case when volte4G.Codec_Registers is null then volte4G.AMR_FR+volte4G.AMR_HR+volte4G.AMR_WB+volte4G.FR+volte4G.EFR+volte4G.HR else volte4G.Codec_Registers end) as codec_samples,
		
		-------------------------------------
		sum(volte4G.[SQNS_NB]) as [NUMBERS OF CALLS Non Sustainability (NB)],
		sum(volte4G.[SQNS_WB]) as [NUMBERS OF CALLS Non Sustainability (WB)],
		sum(volte4G.Started_Ended_2G_Comp) as Calls_Started_2G_WO_Fails,
		sum(volte4G.Started_Ended_3G_Comp) as Calls_Started_3G_WO_Fails,
		sum(volte4G.started_4G_comp) as Calls_Started_4G_WO_Fails,
		sum(volte4G.calls_mixed_comp) as Calls_Mixed,

		-------------------------------------
		sum(vv.VOLTE_Speech_Delay*vv.Count_Speech_Delay) as VOLTE_SpeechDelay_Num,
		sum(vv.Count_Speech_Delay) as VOLTE_SpeechDelay_Den,
		sum(vv.Started_VOLTE) as VOLTE_Calls_Started_Ended_VOLTE,
		sum(vv.SRVCC) as VOLTE_Calls_withSRVCC,
		sum(vv.is_VOLTE) as VOLTE_Calls_is_VOLTE,

		-------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP, 		 
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	from AGGRVOLTE.[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas] volte
			LEFT OUTER JOIN AGGRVOLTE.[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas_4G] volte4G on (isnull(volte4G.parcel,'0.00000 Long, 0.00000 Lat')=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat') and volte4G.mnc=volte.mnc and volte4G.Date_Reporting=volte.Date_Reporting and volte4G.entidad=volte.entidad and volte4G.Aggr_Type=volte.Aggr_Type and volte4G.Report_Type=volte.Report_Type and volte4G.meas_round=volte.meas_round)
			LEFT OUTER JOIN AGGRVOLTE.[dbo].[lcc_aggr_sp_MDD_Voice_VOLTE_4G] vv on (isnull(volte4G.parcel,'0.00000 Long, 0.00000 Lat')=isnull(vv.parcel,'0.00000 Long, 0.00000 Lat') and volte4G.mnc=vv.mnc and volte4G.Date_Reporting=vv.Date_Reporting and volte4G.entidad=vv.entidad and volte4G.Aggr_Type=vv.Aggr_Type and volte4G.Report_Type=vv.Report_Type and volte4G.meas_round=vv.meas_round)
		, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		else p.vf_environment end, volte.mnc,volte.meas_round,volte.Date_Reporting,volte.Week_Reporting,
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 4G Road' 
			else 'VOLTE 4G' end, volte.entidad, volte.Report_Type, volte.aggr_type,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype, volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	---------
	-- VOLTE RealVOLTE:
	insert into _RI_Voice_c
	select 
		volte.calltype as Calltype, 
		p.codigo_ine, case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment, volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week,
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE RealVOLTE Road' 
			else 'VOLTE RealVOLTE' end as meas_Tech, 	1 as info_available, volte.entidad as vf_entity, volte.Report_Type, volte.aggr_type,
	
		sum(volteRV.mo_succeeded+volteRV.mo_blocks+volteRV.mo_drops) as MOC_Calls,
		sum(volteRV.mt_succeeded+volteRV.mt_blocks+volteRV.mt_drops) as MTC_Calls,
		sum(volteRV.mo_blocks) as MOC_Blocks,
		sum(volteRV.mt_blocks) as MTC_Blocks,
		sum(volteRV.mo_drops) as MOC_Drops,
		sum(volteRV.mt_drops) as MTC_Drops,
		sum(volteRV.mo_succeeded+volteRV.mo_blocks+volteRV.mo_drops+volteRV.mt_succeeded+volteRV.mt_blocks+volteRV.mt_drops) as Calls,
		sum(volteRV.mo_blocks+volteRV.mt_blocks) as Blocks,
		sum(volteRV.mo_drops+volteRV.mt_drops) as Drops,
		sum(volteRV.[CR_Affected_Calls]) as CR_Affected_Calls,
		sum(volteRV.duration_3g) as Call_duration_3G,
		sum(volteRV.duration_2g) as Call_duration_2G,
		sum(volteRV.duration_3g+volteRV.duration_2g) as Call_duration_tech_samples,
		sum(volteRV.gsm_calls_after_csfb_comp) as CSFB_to_GSM_samples,
		sum(volteRV.UMTS_Calls_after_csfb_comp) as CSFB_to_UMTS_samples,
		sum(volteRV.gsm_calls_after_csfb_comp+volteRV.UMTS_Calls_after_csfb_comp) as CSFB_samples,

		sum(case when volteRV.Codec_Registers is null then volteRV.AMR_FR else volteRV.AMR_FR_Count end) as AMR_FR_samples,
		sum(case when volteRV.Codec_Registers is null then volteRV.AMR_HR else volteRV.AMR_HR_Count end) as AMR_HR_samples,
		sum(case when volteRV.Codec_Registers is null then volteRV.AMR_WB else volteRV.AMR_WB_Count end) as AMR_WB_samples,
		sum(case when volteRV.Codec_Registers is null then volteRV.FR else volteRV.FR_Count end) as FR_samples,
		sum(case when volteRV.Codec_Registers is null then volteRV.EFR else volteRV.EFR_Count end) as EFR_samples,
		sum(case when volteRV.Codec_Registers is null then volteRV.HR else volteRV.HR_Count end) as HR_samples,
		sum(case when volteRV.Codec_Registers is null then volteRV.AMR_FR+volteRV.AMR_HR+volteRV.AMR_WB+volteRV.FR+volteRV.EFR+volteRV.HR else volteRV.Codec_Registers end) as codec_samples,
		
		-------------------------------------
		sum(volteRV.[SQNS_NB]) as [NUMBERS OF CALLS Non Sustainability (NB)],
		sum(volteRV.[SQNS_WB]) as [NUMBERS OF CALLS Non Sustainability (WB)],
		sum(volteRV.Started_Ended_2G_Comp) as Calls_Started_2G_WO_Fails,
		sum(volteRV.Started_Ended_3G_Comp) as Calls_Started_3G_WO_Fails,
		sum(volteRV.started_4G_comp) as Calls_Started_4G_WO_Fails,
		sum(volteRV.calls_mixed_comp) as Calls_Mixed,

		-------------------------------------
		sum(vv.VOLTE_Speech_Delay*vv.Count_Speech_Delay) as VOLTE_SpeechDelay_Num,
		sum(vv.Count_Speech_Delay) as VOLTE_SpeechDelay_Den,
		sum(vv.Started_VOLTE) as VOLTE_Calls_Started_Ended_VOLTE,
		sum(vv.SRVCC) as VOLTE_Calls_withSRVCC,
		sum(vv.is_VOLTE) as VOLTE_Calls_is_VOLTE,

		---------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%'then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%'then volte.Region_OSP
		--else null end as Region_Road_OSP, 		 
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	from AGGRVOLTE.[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas] volte
			LEFT OUTER JOIN AGGRVOLTE.[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas_VOLTE] volteRV on (isnull(volteRV.parcel,'0.00000 Long, 0.00000 Lat')=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat') and volteRV.mnc=volte.mnc and volteRV.Date_Reporting=volte.Date_Reporting and volteRV.entidad=volte.entidad and volteRV.Aggr_Type=volte.Aggr_Type and volteRV.Report_Type=volte.Report_Type and volteRV.meas_round=volte.meas_round)
			LEFT OUTER JOIN AGGRVOLTE.[dbo].[lcc_aggr_sp_MDD_Voice_VOLTE_VOLTE] vv on (isnull(volteRV.parcel,'0.00000 Long, 0.00000 Lat')=isnull(vv.parcel,'0.00000 Long, 0.00000 Lat') and volteRV.mnc=vv.mnc and volteRV.Date_Reporting=vv.Date_Reporting and volteRV.entidad=vv.entidad and volteRV.Aggr_Type=vv.Aggr_Type and volteRV.Report_Type=vv.Report_Type and volteRV.meas_round=vv.meas_round)
		, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		else p.vf_environment end, volte.mnc,volte.meas_round,volte.Date_Reporting,volte.Week_Reporting,
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE RealVOLTE Road' 
			else 'VOLTE RealVOLTE' end, volte.entidad, volte.Report_Type, volte.aggr_type, 
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%'then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%'then volte.Region_OSP
		--else null end, 
		volte.calltype, volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	---------
	-- VOLTE 3G:
	insert into _RI_Voice_c
	select  
		volte.calltype as Calltype,
		p.codigo_ine, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment, volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week,
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 3G Road' 
			else 'VOLTE 3G' end as meas_Tech, 1 as info_available, volte.entidad as vf_entity, volte.Report_Type, volte.aggr_type,
	
		sum(volte3G.mo_succeeded+volte3G.mo_blocks+volte3G.mo_drops) as MOC_Calls,
		sum(volte3G.mt_succeeded+volte3G.mt_blocks+volte3G.mt_drops) as MTC_Calls,
		sum(volte3G.mo_blocks) as MOC_Blocks,
		sum(volte3G.mt_blocks) as MTC_Blocks,
		sum(volte3G.mo_drops) as MOC_Drops,
		sum(volte3G.mt_drops) as MTC_Drops,
		sum(volte3G.mo_succeeded+volte3G.mo_blocks+volte3G.mo_drops+volte3G.mt_succeeded+volte3G.mt_blocks+volte3G.mt_drops) as Calls,
		sum(volte3G.mo_blocks+volte3G.mt_blocks) as Blocks,
		sum(volte3G.mo_drops+volte3G.mt_drops) as Drops,
		sum(volte3G.[CR_Affected_Calls]) as CR_Affected_Calls,

		sum(volte3G.duration_3g) as Call_duration_3G,
		sum(volte3G.duration_2g) as Call_duration_2G,
		sum(volte3G.duration_3g+volte3G.duration_2g) as Call_duration_tech_samples,
		sum(volte3G.gsm_calls_after_csfb_comp) as CSFB_to_GSM_samples,
		sum(volte3G.UMTS_Calls_after_csfb_comp) as CSFB_to_UMTS_samples,
		sum(volte3G.gsm_calls_after_csfb_comp+volte3G.UMTS_Calls_after_csfb_comp) as CSFB_samples,

		sum(case when volte3G.Codec_Registers is null then volte3G.AMR_FR else volte3G.AMR_FR_Count end) as AMR_FR_samples,
		sum(case when volte3G.Codec_Registers is null then volte3G.AMR_HR else volte3G.AMR_HR_Count end) as AMR_HR_samples,
		sum(case when volte3G.Codec_Registers is null then volte3G.AMR_WB else volte3G.AMR_WB_Count end) as AMR_WB_samples,
		sum(case when volte3G.Codec_Registers is null then volte3G.FR else volte3G.FR_Count end) as FR_samples,
		sum(case when volte3G.Codec_Registers is null then volte3G.EFR else volte3G.EFR_Count end) as EFR_samples,
		sum(case when volte3G.Codec_Registers is null then volte3G.HR else volte3G.HR_Count end) as HR_samples,
		sum(case when volte3G.Codec_Registers is null then volte3G.AMR_FR+volte3G.AMR_HR+volte3G.AMR_WB+volte3G.FR+volte3G.EFR+volte3G.HR else volte3G.Codec_Registers end) as codec_samples,
		
		-------------------------------------
		sum(volte3G.[SQNS_NB]) as [NUMBERS OF CALLS Non Sustainability (NB)],
		sum(volte3G.[SQNS_WB]) as [NUMBERS OF CALLS Non Sustainability (WB)],
		sum(volte3G.Started_Ended_2G_Comp) as Calls_Started_2G_WO_Fails,
		sum(volte3G.Started_Ended_3G_Comp) as Calls_Started_3G_WO_Fails,
		sum(volte3G.started_4G_comp) as Calls_Started_4G_WO_Fails,
		sum(volte3G.calls_mixed_comp) as Calls_Mixed,

		-------------------------------------
		sum(0) as VOLTE_SpeechDelay_Num,		-- no se agrega esta info en las llamadas de 3G de VOLTE, no tiene sentido estos campos en 3G aunque los estemos sacando en el DASH
		sum(0) as VOLTE_SpeechDelay_Den,
		sum(0) as VOLTE_Calls_Started_Ended_VOLTE,
		sum(0) as VOLTE_Calls_withSRVCC,
		sum(0) as VOLTE_Calls_is_VOLTE,

		-------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%'then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%'then volte.Region_OSP
		--else null end as Region_Road_OSP, 		 
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	from AGGRVOLTE.[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas] volte
			LEFT OUTER JOIN AGGRVOLTE.[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas_3G] volte3G on (isnull(volte3G.parcel,'0.00000 Long, 0.00000 Lat')=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat') and volte3G.mnc=volte.mnc and volte3G.Date_Reporting=volte.Date_Reporting and volte3G.entidad=volte.entidad and volte3G.Aggr_Type=volte.Aggr_Type and volte3G.Report_Type=volte.Report_Type and volte3G.meas_round=volte.meas_round)
		, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		else p.vf_environment end, volte.mnc,volte.meas_round,volte.Date_Reporting,volte.Week_Reporting,
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 3G Road' 
			else 'VOLTE 3G' end, volte.entidad, volte.Report_Type, volte.aggr_type, 
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%'then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%'then volte.Region_OSP
		--else null end, 
		volte.calltype, volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 1.3 Llamadas VOLTE - ALL, 4G, RealVOLTE, 3G', getdate()


	------------------------------------------------------------------------------
	-- 2.1 MOS 3G, 4G y Road and 4GOnly y Road 4GOnly 
	-- Añadido info VOLTE (aLL, 4G, RealVOLTE, 3G)
	------------------------------------------------------------------------------
	print '2.1 MOS 3G, 4G y 4G_Road'
	-----------	 
	-- 3G:
	insert into _RI_Voice_m
	select 
		t.calltype as Calltype,
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,t.mnc,t.meas_round,t.Date_Reporting as meas_date,t.Week_Reporting as meas_week, 
	   '3G' as meas_Tech, 1 as info_available, t.entidad as vf_entity, t.Report_Type, t.aggr_type,
	
		1.0*(sum(t.[MOS_ALL]*t.calls_mos)) as MOS_Num,
		sum(t.calls_mos) as MOS_Samples    

		--- FJLA 2016 09 13 adding mos pdf
		,sum(isnull([1-1.5 WB],0)) as [1_WB]
		,sum(isnull([1.5-2 WB],0)) as [2_WB]
		,sum(isnull([2-2.5 WB],0)) as [3_WB]
		,sum(isnull([2.5-3 WB],0)) as [4_WB]
		,sum(isnull([3-3.5 WB],0)) as [5_WB]
		,sum(isnull([3.5-4 WB],0)) as [6_WB]
		,sum(isnull([4-4.5 WB],0)) as [7_WB]
		,sum(isnull([4.5-5 WB],0)) as [8_WB]

		,sum(isnull([1-1.5 WB],0)+ isnull([1.5-2 WB],0)+ isnull([2-2.5 WB],0)+ isnull([2.5-3 WB],0) +
		 isnull([3-3.5 WB],0) +isnull([3.5-4 WB],0)+ isnull([4-4.5 WB],0)+ isnull([4.5-5 WB],0))  as [MOS ALL Samples WB]

		,sum(isnull([1-1.5 WB],0)+ isnull([1.5-2 WB],0)+ isnull([2-2.5 WB],0)) as [MOS Below 2.5 Samples WB] 
		,sum(isnull([3.5-4 WB],0)+ isnull([4-4.5 WB],0)+ isnull([4.5-5 WB],0)) as [MOS Over 3.5 Samples WB] 

		,sum(isnull([1-1.5 NB],0)) as [1_NB]
		,sum(isnull([1.5-2 NB],0)) as [2_NB]
		,sum(isnull([2-2.5 NB],0)) as [3_NB]
		,sum(isnull([2.5-3 NB],0)) as [4_NB]
		,sum(isnull([3-3.5 NB],0)) as [5_NB]
		,sum(isnull([3.5-4 NB],0)) as [6_NB]
		,sum(isnull([4-4.5 NB],0)) as [7_NB]
		,sum(isnull([4.5-5 NB],0)) as [8_NB]

		,sum(isnull([1-1.5 NB],0)+ isnull([1.5-2 NB],0)+ isnull([2-2.5 NB],0)+ isnull([2.5-3 NB],0) +
		 isnull([3-3.5 NB],0) +isnull([3.5-4 NB],0)+ isnull([4-4.5 NB],0)+ isnull([4.5-5 NB],0))  as [MOS ALL Samples NB]

		,sum(isnull([1-1.5 NB],0)+ isnull([1.5-2 NB],0)+ isnull([2-2.5 NB],0)) as [MOS Below 2.5 Samples NB]
		,sum(isnull([3.5-4 NB],0)+ isnull([4-4.5 NB],0)+ isnull([4.5-5 NB],0)) as [MOS Over 3.5 Samples NB],

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(t.[MOS_Samples_Under_2.5]) as [MOS_Samples_Under_2.5],
		sum(t.[MOS_NB_Samples_Under_2.5]) as [MOS_NB_Samples_Under_2.5],
		sum(t.Registers+t.Registers_NB) as [Samples_DL+UL],
		sum(t.Registers_NB) as [Samples_DL+UL_NB],
		sum(t.Calls_WB_Only) as [WB AMR Only],
		sum(t.Calls_WB_Only)*sum(t.MOS_WBOnly) as [Avg WB AMR Only],

		---------------------------------
		/*kpis nuevos añadidos para DASH*/	
		1.0*(sum(t.mos_nb*t.Calls_MOS_NB)) as MOS_NB_Num,
		sum(t.Calls_MOS_NB) as MOS_NB_Den,
		1.0*sum(t.[MOS_WBOnly]*t.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Num],
		sum(t.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Den],
		sum(t.[MOS_Samples_Under_2.5]+t.[MOS_NB_Samples_Under_2.5]) as [MOS_Overall_Samples_Under_2.5],

		---------------------------------
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_VF end as Region_Road_VF,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_OSP end as Region_Road_OSP,
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]

	from	[AGGRVoice3G].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ] t, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')	
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end  ,t.mnc,t.meas_round,t.Date_reporting,t.week_reporting, t.entidad,t.Report_Type,t.Aggr_Type
		,t.calltype, t.[ASideDevice], t.[BSideDevice], t.[SWVersion]--,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_VF end,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_OSP end

	---------
	-- 4G:
	insert into _RI_Voice_m
	select
		t.calltype as Calltype,
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,t.mnc,t.meas_round,t.Date_Reporting as meas_date,t.Week_Reporting as meas_week, 
	   '4G' as meas_Tech, 1 as info_available, t.entidad as vf_entity, t.Report_Type, t.aggr_type,
	
		1.0*(sum(t.[MOS_ALL]*t.calls_mos)) as MOS_Num,
		sum(t.calls_mos) as MOS_Samples

		--- FJLA 2016 09 13 adding mos pdf
		,sum(isnull([1-1.5 WB],0)) as [1_WB]
		,sum(isnull([1.5-2 WB],0)) as [2_WB]
		,sum(isnull([2-2.5 WB],0)) as [3_WB]
		,sum(isnull([2.5-3 WB],0)) as [4_WB]
		,sum(isnull([3-3.5 WB],0)) as [5_WB]
		,sum(isnull([3.5-4 WB],0)) as [6_WB]
		,sum(isnull([4-4.5 WB],0)) as [7_WB]
		,sum(isnull([4.5-5 WB],0)) as [8_WB]

		,sum(isnull([1-1.5 WB],0)+ isnull([1.5-2 WB],0)+ isnull([2-2.5 WB],0)+ isnull([2.5-3 WB],0) +
		 isnull([3-3.5 WB],0) +isnull([3.5-4 WB],0)+ isnull([4-4.5 WB],0)+ isnull([4.5-5 WB],0))  as [MOS ALL Samples WB]

		,sum(isnull([1-1.5 WB],0)+ isnull([1.5-2 WB],0)+ isnull([2-2.5 WB],0)) as [MOS Below 2.5 Samples WB] 
		,sum(isnull([3.5-4 WB],0)+ isnull([4-4.5 WB],0)+ isnull([4.5-5 WB],0)) as [MOS Over 3.5 Samples WB] 

		,sum(isnull([1-1.5 NB],0)) as [1_NB]
		,sum(isnull([1.5-2 NB],0)) as [2_NB]
		,sum(isnull([2-2.5 NB],0)) as [3_NB]
		,sum(isnull([2.5-3 NB],0)) as [4_NB]
		,sum(isnull([3-3.5 NB],0)) as [5_NB]
		,sum(isnull([3.5-4 NB],0)) as [6_NB]
		,sum(isnull([4-4.5 NB],0)) as [7_NB]
		,sum(isnull([4.5-5 NB],0)) as [8_NB]

		,sum(isnull([1-1.5 NB],0)+ isnull([1.5-2 NB],0)+ isnull([2-2.5 NB],0)+ isnull([2.5-3 NB],0) +
		 isnull([3-3.5 NB],0) +isnull([3.5-4 NB],0)+ isnull([4-4.5 NB],0)+ isnull([4.5-5 NB],0))  as [MOS ALL Samples NB]

		,sum(isnull([1-1.5 NB],0)+ isnull([1.5-2 NB],0)+ isnull([2-2.5 NB],0)) as [MOS Below 2.5 Samples NB]
		,sum(isnull([3.5-4 NB],0)+ isnull([4-4.5 NB],0)+ isnull([4.5-5 NB],0)) as [MOS Over 3.5 Samples NB],

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(t.[MOS_Samples_Under_2.5]) as [MOS_Samples_Under_2.5],
		sum(t.[MOS_NB_Samples_Under_2.5]) as [MOS_NB_Samples_Under_2.5],	
		sum(t.Registers+t.Registers_NB) as [Samples_DL+UL],
		sum(t.Registers_NB) as [Samples_DL+UL_NB],
		sum(t.Calls_WB_Only) as [WB AMR Only],
		sum(t.Calls_WB_Only)*sum(t.MOS_WBOnly) as [Avg WB AMR Only],

		---------------------------------
		/*kpis nuevos añadidos para DASH*/	
		1.0*(sum(t.mos_nb*t.Calls_MOS_NB)) as MOS_NB_Num,
		sum(t.Calls_MOS_NB) as MOS_NB_Den,
		1.0*sum(t.[MOS_WBOnly]*t.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Num],
		sum(t.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Den],
		sum(t.[MOS_Samples_Under_2.5]+t.[MOS_NB_Samples_Under_2.5]) as [MOS_Overall_Samples_Under_2.5],

		---------------------------------
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_VF end as Region_Road_VF,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_OSP end as Region_Road_OSP,
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]

	from	[AGGRVoice4G].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ] t, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end ,t.mnc,t.meas_round,t.Date_reporting,t.week_reporting, t.entidad, t.Report_Type, t.Aggr_Type
		,t.calltype, t.[ASideDevice], t.[BSideDevice], t.[SWVersion]--,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_VF end,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_OSP end
     
	---------
	-- Road 4G:
	insert into _RI_Voice_m
	select 
		t.Calltype as Calltype,
		p.codigo_ine, 'Roads' vf_environment,t.mnc,t.meas_round,t.Date_Reporting as meas_date,t.Week_Reporting as meas_week, 
	   'Road 4G' as meas_Tech, 1 as info_available, t.entidad as vf_entity, t.Report_Type, t.aggr_type,
		
		1.0*(sum(t.[MOS_ALL]*t.calls_mos)) as MOS_Num,
		sum(t.calls_mos) as MOS_Samples    
	
		--- FJLA 2016 09 13 adding mos pdf
		,sum(isnull([1-1.5 WB],0)) as [1_WB]
		,sum(isnull([1.5-2 WB],0)) as [2_WB]
		,sum(isnull([2-2.5 WB],0)) as [3_WB]
		,sum(isnull([2.5-3 WB],0)) as [4_WB]
		,sum(isnull([3-3.5 WB],0)) as [5_WB]
		,sum(isnull([3.5-4 WB],0)) as [6_WB]
		,sum(isnull([4-4.5 WB],0)) as [7_WB]
		,sum(isnull([4.5-5 WB],0)) as [8_WB]

		,sum(isnull([1-1.5 WB],0)+ isnull([1.5-2 WB],0)+ isnull([2-2.5 WB],0)+ isnull([2.5-3 WB],0) +
		 isnull([3-3.5 WB],0) +isnull([3.5-4 WB],0)+ isnull([4-4.5 WB],0)+ isnull([4.5-5 WB],0))  as [MOS ALL Samples WB]

		,sum(isnull([1-1.5 WB],0)+ isnull([1.5-2 WB],0)+ isnull([2-2.5 WB],0)) as [MOS Below 2.5 Samples WB] 
		,sum(isnull([3.5-4 WB],0)+ isnull([4-4.5 WB],0)+ isnull([4.5-5 WB],0)) as [MOS Over 3.5 Samples WB] 

		,sum(isnull([1-1.5 NB],0)) as [1_NB]
		,sum(isnull([1.5-2 NB],0)) as [2_NB]
		,sum(isnull([2-2.5 NB],0)) as [3_NB]
		,sum(isnull([2.5-3 NB],0)) as [4_NB]
		,sum(isnull([3-3.5 NB],0)) as [5_NB]
		,sum(isnull([3.5-4 NB],0)) as [6_NB]
		,sum(isnull([4-4.5 NB],0)) as [7_NB]
		,sum(isnull([4.5-5 NB],0)) as [8_NB]

		,sum(isnull([1-1.5 NB],0)+ isnull([1.5-2 NB],0)+ isnull([2-2.5 NB],0)+ isnull([2.5-3 NB],0) +
		 isnull([3-3.5 NB],0) +isnull([3.5-4 NB],0)+ isnull([4-4.5 NB],0)+ isnull([4.5-5 NB],0))  as [MOS ALL Samples NB]

		,sum(isnull([1-1.5 NB],0)+ isnull([1.5-2 NB],0)+ isnull([2-2.5 NB],0)) as [MOS Below 2.5 Samples NB]
		,sum(isnull([3.5-4 NB],0)+ isnull([4-4.5 NB],0)+ isnull([4.5-5 NB],0)) as [MOS Over 3.5 Samples NB],

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(t.[MOS_Samples_Under_2.5]) as [MOS_Samples_Under_2.5],
		sum(t.[MOS_NB_Samples_Under_2.5]) as [MOS_NB_Samples_Under_2.5],	
		sum(t.Registers+t.Registers_NB) as [Samples_DL+UL],
		sum(t.Registers_NB) as [Samples_DL+UL_NB],
		sum(t.Calls_WB_Only) as [WB AMR Only],
		sum(t.Calls_WB_Only)*sum(t.MOS_WBOnly) as [Avg WB AMR Only],

		---------------------------------
		/*kpis nuevos añadidos para DASH*/	
		1.0*(sum(t.mos_nb*t.Calls_MOS_NB)) as MOS_NB_Num,
		sum(t.Calls_MOS_NB) as MOS_NB_Den,
		1.0*sum(t.[MOS_WBOnly]*t.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Num],
		sum(t.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Den],
		sum(t.[MOS_Samples_Under_2.5]+t.[MOS_NB_Samples_Under_2.5]) as [MOS_Overall_Samples_Under_2.5],

		---------------------------------
		--t.Region_VF as Region_Road_VF, t.Region_OSP as Region_Road_OSP,
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]

	from	[AGGRVoice4G_Road].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ] t, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,t.mnc,t.meas_round,t.Date_reporting,t.week_reporting, t.entidad, t.Report_Type, t.Aggr_Type, t.calltype,
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]--, t.Region_VF, t.Region_OSP

	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 2.1 MOS 3G, 4G y 4G_Road', getdate()


	-------------------------------------------------------------------------------------------------------------
	/*			2.2. Cruzamos con la tabla de 4G para saber qué entidades tenemos que reportar para 4GOnly. 
					 Si una medida no ha cursado nada en esta tecnología saldría vacía.							*/
	-------------------------------------------------------------------------------------------------------------- 
	print '2.2 MOS 4GOnly y 4GOnly_Road'
	-----------	
	-- 4G Only:
	insert into _RI_Voice_m
	select
		t.calltype as Calltype,
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,t.mnc,t.meas_round,t.Date_Reporting as meas_date,t.Week_Reporting as meas_week, 
	   '4GOnly' as meas_Tech, 1 as info_available, t.entidad as vf_entity, t.Report_Type, t.aggr_type,

		1.0*(sum(M4G.[MOS_ALL]*M4G.calls_mos)) as MOS_Num,
		sum(M4G.calls_mos) as MOS_Samples

		--- FJLA 2016 09 13 adding mos pdf
		,sum(isnull(M4G.[1-1.5 WB],0)) as [1_WB]
		,sum(isnull(M4G.[1.5-2 WB],0)) as [2_WB]
		,sum(isnull(M4G.[2-2.5 WB],0)) as [3_WB]
		,sum(isnull(M4G.[2.5-3 WB],0)) as [4_WB]
		,sum(isnull(M4G.[3-3.5 WB],0)) as [5_WB]
		,sum(isnull(M4G.[3.5-4 WB],0)) as [6_WB]
		,sum(isnull(M4G.[4-4.5 WB],0)) as [7_WB]
		,sum(isnull(M4G.[4.5-5 WB],0)) as [8_WB]

		,sum(isnull(M4G.[1-1.5 WB],0)+ isnull(M4G.[1.5-2 WB],0)+ isnull(M4G.[2-2.5 WB],0)+ isnull(M4G.[2.5-3 WB],0) +
		 isnull(M4G.[3-3.5 WB],0) +isnull(M4G.[3.5-4 WB],0)+ isnull(M4G.[4-4.5 WB],0)+ isnull(M4G.[4.5-5 WB],0))  as [MOS ALL Samples WB]

		,sum(isnull(M4G.[1-1.5 WB],0)+ isnull(M4G.[1.5-2 WB],0)+ isnull(M4G.[2-2.5 WB],0)) as [MOS Below 2.5 Samples WB] 
		,sum(isnull(M4G.[3.5-4 WB],0)+ isnull(M4G.[4-4.5 WB],0)+ isnull(M4G.[4.5-5 WB],0)) as [MOS Over 3.5 Samples WB] 

		,sum(isnull(M4G.[1-1.5 NB],0)) as [1_NB]
		,sum(isnull(M4G.[1.5-2 NB],0)) as [2_NB]
		,sum(isnull(M4G.[2-2.5 NB],0)) as [3_NB]
		,sum(isnull(M4G.[2.5-3 NB],0)) as [4_NB]
		,sum(isnull(M4G.[3-3.5 NB],0)) as [5_NB]
		,sum(isnull(M4G.[3.5-4 NB],0)) as [6_NB]
		,sum(isnull(M4G.[4-4.5 NB],0)) as [7_NB]
		,sum(isnull(M4G.[4.5-5 NB],0)) as [8_NB]

		,sum(isnull(M4G.[1-1.5 NB],0)+ isnull(M4G.[1.5-2 NB],0)+ isnull(M4G.[2-2.5 NB],0)+ isnull(M4G.[2.5-3 NB],0) +
		 isnull(M4G.[3-3.5 NB],0) +isnull(M4G.[3.5-4 NB],0)+ isnull(M4G.[4-4.5 NB],0)+ isnull(M4G.[4.5-5 NB],0))  as [MOS ALL Samples NB]

		,sum(isnull(M4G.[1-1.5 NB],0)+ isnull(M4G.[1.5-2 NB],0)+ isnull(M4G.[2-2.5 NB],0)) as [MOS Below 2.5 Samples NB]
		,sum(isnull(M4G.[3.5-4 NB],0)+ isnull(M4G.[4-4.5 NB],0)+ isnull(M4G.[4.5-5 NB],0)) as [MOS Over 3.5 Samples NB],

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(M4G.[MOS_Samples_Under_2.5]) as [MOS_Samples_Under_2.5],
		sum(M4G.[MOS_NB_Samples_Under_2.5]) as [MOS_NB_Samples_Under_2.5],	
		sum(M4G.Registers+M4G.Registers_NB) as [Samples_DL+UL],
		sum(M4G.Registers_NB) as [Samples_DL+UL_NB],
		sum(M4G.Calls_WB_Only) as [WB AMR Only],
		sum(M4G.Calls_WB_Only)*sum(M4G.MOS_WBOnly) as [Avg WB AMR Only],

		---------------------------------
		/*kpis nuevos añadidos para DASH*/	
		1.0*(sum(M4G.mos_nb*M4G.Calls_MOS_NB)) as MOS_NB_Num,
		sum(M4G.Calls_MOS_NB) as MOS_NB_Den,
		1.0*sum(M4G.[MOS_WBOnly]*M4G.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Num],
		sum(M4G.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Den],
		sum(M4G.[MOS_Samples_Under_2.5]+M4G.[MOS_NB_Samples_Under_2.5]) as [MOS_Overall_Samples_Under_2.5],

		---------------------------------
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_VF end as Region_Road_VF,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_OSP end as Region_Road_OSP,
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]

	from [AGGRVoice4G].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ] t 
			left outer join [AGGRVoice4G].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ_4G] M4G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(M4G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=M4G.mnc and t.Date_Reporting=M4G.Date_Reporting and t.entidad=M4G.entidad and t.Aggr_Type=M4G.Aggr_Type and t.Report_Type=M4G.Report_Type and t.meas_round=M4G.meas_round)
		,[AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end ,t.mnc,t.meas_round,t.Date_reporting,t.week_reporting, t.entidad, t.Report_Type, t.Aggr_Type
		,t.calltype, t.[ASideDevice], t.[BSideDevice], t.[SWVersion]--,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_VF end,
		--case when t.entidad like 'AVE-%' or t.entidad like 'MAD-___-R[0-9]%' then  'AVE' else t.Region_OSP end

	---------
	-- Road 4GOnly:
	insert into _RI_Voice_m
	select 
		t.Calltype as Calltype,
		p.codigo_ine, 'Roads' vf_environment,t.mnc,t.meas_round,t.Date_Reporting as meas_date,t.Week_Reporting as meas_week, 
	   'Road 4GOnly' as meas_Tech, 1 as info_available, t.entidad as vf_entity, t.Report_Type, t.aggr_type,
	
		1.0*(sum(M4G.[MOS_ALL]*M4G.calls_mos)) as MOS_Num,
		sum(M4G.calls_mos) as MOS_Samples  
	  
		--- FJLA 2016 09 13 adding mos pdf
		,sum(isnull(M4G.[1-1.5 WB],0)) as [1_WB]
		,sum(isnull(M4G.[1.5-2 WB],0)) as [2_WB]
		,sum(isnull(M4G.[2-2.5 WB],0)) as [3_WB]
		,sum(isnull(M4G.[2.5-3 WB],0)) as [4_WB]
		,sum(isnull(M4G.[3-3.5 WB],0)) as [5_WB]
		,sum(isnull(M4G.[3.5-4 WB],0)) as [6_WB]
		,sum(isnull(M4G.[4-4.5 WB],0)) as [7_WB]
		,sum(isnull(M4G.[4.5-5 WB],0)) as [8_WB]

		,sum(isnull(M4G.[1-1.5 WB],0)+ isnull(M4G.[1.5-2 WB],0)+ isnull(M4G.[2-2.5 WB],0)+ isnull(M4G.[2.5-3 WB],0) +
		 isnull(M4G.[3-3.5 WB],0) +isnull(M4G.[3.5-4 WB],0)+ isnull(M4G.[4-4.5 WB],0)+ isnull(M4G.[4.5-5 WB],0))  as [MOS ALL Samples WB]

		,sum(isnull(M4G.[1-1.5 WB],0)+ isnull(M4G.[1.5-2 WB],0)+ isnull(M4G.[2-2.5 WB],0)) as [MOS Below 2.5 Samples WB] 
		,sum(isnull(M4G.[3.5-4 WB],0)+ isnull(M4G.[4-4.5 WB],0)+ isnull(M4G.[4.5-5 WB],0)) as [MOS Over 3.5 Samples WB] 

		,sum(isnull(M4G.[1-1.5 NB],0)) as [1_NB]
		,sum(isnull(M4G.[1.5-2 NB],0)) as [2_NB]
		,sum(isnull(M4G.[2-2.5 NB],0)) as [3_NB]
		,sum(isnull(M4G.[2.5-3 NB],0)) as [4_NB]
		,sum(isnull(M4G.[3-3.5 NB],0)) as [5_NB]
		,sum(isnull(M4G.[3.5-4 NB],0)) as [6_NB]
		,sum(isnull(M4G.[4-4.5 NB],0)) as [7_NB]
		,sum(isnull(M4G.[4.5-5 NB],0)) as [8_NB]

		,sum(isnull(M4G.[1-1.5 NB],0)+ isnull(M4G.[1.5-2 NB],0)+ isnull(M4G.[2-2.5 NB],0)+ isnull(M4G.[2.5-3 NB],0) +
		 isnull(M4G.[3-3.5 NB],0) +isnull(M4G.[3.5-4 NB],0)+ isnull(M4G.[4-4.5 NB],0)+ isnull(M4G.[4.5-5 NB],0))  as [MOS ALL Samples NB]

		,sum(isnull(M4G.[1-1.5 NB],0)+ isnull(M4G.[1.5-2 NB],0)+ isnull(M4G.[2-2.5 NB],0)) as [MOS Below 2.5 Samples NB]
		,sum(isnull(M4G.[3.5-4 NB],0)+ isnull(M4G.[4-4.5 NB],0)+ isnull(M4G.[4.5-5 NB],0)) as [MOS Over 3.5 Samples NB],

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(M4G.[MOS_Samples_Under_2.5]) as [MOS_Samples_Under_2.5],
		sum(M4G.[MOS_NB_Samples_Under_2.5]) as [MOS_NB_Samples_Under_2.5],	
		sum(M4G.Registers+M4G.Registers_NB) as [Samples_DL+UL],
		sum(M4G.Registers_NB) as [Samples_DL+UL_NB],
		sum(M4G.Calls_WB_Only) as [WB AMR Only],
		sum(M4G.Calls_WB_Only)*sum(M4G.MOS_WBOnly) as [Avg WB AMR Only],

		---------------------------------
		/*kpis nuevos añadidos para DASH*/	
		1.0*(sum(M4G.mos_nb*M4G.Calls_MOS_NB)) as MOS_NB_Num,
		sum(M4G.Calls_MOS_NB) as MOS_NB_Den,
		1.0*sum(M4G.[MOS_WBOnly]*M4G.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Num],
		sum(M4G.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Den],
		sum(M4G.[MOS_Samples_Under_2.5]+M4G.[MOS_NB_Samples_Under_2.5]) as [MOS_Overall_Samples_Under_2.5],

		---------------------------------
		--t.Region_VF as Region_Road_VF, t.Region_OSP as Region_Road_OSP,
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]

	from	[AGGRVoice4G_Road].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ] t
				left outer join  [AGGRVoice4G_Road].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ_4G] M4G on (isnull(t.parcel,'0.00000 Long, 0.00000 Lat')=isnull(M4G.parcel,'0.00000 Long, 0.00000 Lat') and t.mnc=M4G.mnc and t.Date_Reporting=M4G.Date_Reporting and t.entidad=M4G.entidad and t.Aggr_Type=M4G.Aggr_Type and t.Report_Type=M4G.Report_Type and t.meas_round=M4G.meas_round) 
			,[AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(t.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,t.mnc,t.meas_round,t.Date_reporting,t.week_reporting, t.entidad, t.Report_Type, t.Aggr_Type, t.calltype,
		t.[ASideDevice], t.[BSideDevice], t.[SWVersion]--, t.Region_VF, t.Region_OSP

	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 2.2 MOS 4GOnly y 4GOnly_Road', getdate()


	--------------------------------------------------------------------------------------
	/*			2.3 Se añade info VOLTE - ALL, 4G, RealVOLTE, 3G							*/
	-------------------------------------------------------------------------------------- 
	print '2.3 MOS VOLTE - ALL, 4G, RealVOLTE, 3G'
	-----------	
	-- VOLTE ALL:
	insert into _RI_Voice_m
	select 
		volte.calltype as Calltype,
		p.codigo_ine, case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment, volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE ALL Road' 
			else 'VOLTE ALL' end as meas_Tech, 1 as info_available, volte.entidad as vf_entity, volte.Report_Type, volte.aggr_type,

		1.0*(sum(volte.[MOS_ALL]*volte.calls_mos)) as MOS_Num,
		sum(volte.calls_mos) as MOS_Samples

		--- FJLA 2016 09 13 adding mos pdf
		,sum(isnull(volte.[1-1.5 WB],0)) as [1_WB]
		,sum(isnull(volte.[1.5-2 WB],0)) as [2_WB]
		,sum(isnull(volte.[2-2.5 WB],0)) as [3_WB]
		,sum(isnull(volte.[2.5-3 WB],0)) as [4_WB]
		,sum(isnull(volte.[3-3.5 WB],0)) as [5_WB]
		,sum(isnull(volte.[3.5-4 WB],0)) as [6_WB]
		,sum(isnull(volte.[4-4.5 WB],0)) as [7_WB]
		,sum(isnull(volte.[4.5-5 WB],0)) as [8_WB]

		,sum(isnull(volte.[1-1.5 WB],0)+ isnull(volte.[1.5-2 WB],0)+ isnull(volte.[2-2.5 WB],0)+ isnull(volte.[2.5-3 WB],0) +
		 isnull(volte.[3-3.5 WB],0) +isnull(volte.[3.5-4 WB],0)+ isnull(volte.[4-4.5 WB],0)+ isnull(volte.[4.5-5 WB],0))  as [MOS ALL Samples WB]

		,sum(isnull(volte.[1-1.5 WB],0)+ isnull(volte.[1.5-2 WB],0)+ isnull(volte.[2-2.5 WB],0)) as [MOS Below 2.5 Samples WB] 
		,sum(isnull(volte.[3.5-4 WB],0)+ isnull(volte.[4-4.5 WB],0)+ isnull(volte.[4.5-5 WB],0)) as [MOS Over 3.5 Samples WB] 

		,sum(isnull(volte.[1-1.5 NB],0)) as [1_NB]
		,sum(isnull(volte.[1.5-2 NB],0)) as [2_NB]
		,sum(isnull(volte.[2-2.5 NB],0)) as [3_NB]
		,sum(isnull(volte.[2.5-3 NB],0)) as [4_NB]
		,sum(isnull(volte.[3-3.5 NB],0)) as [5_NB]
		,sum(isnull(volte.[3.5-4 NB],0)) as [6_NB]
		,sum(isnull(volte.[4-4.5 NB],0)) as [7_NB]
		,sum(isnull(volte.[4.5-5 NB],0)) as [8_NB]

		,sum(isnull(volte.[1-1.5 NB],0)+ isnull(volte.[1.5-2 NB],0)+ isnull(volte.[2-2.5 NB],0)+ isnull(volte.[2.5-3 NB],0) +
		 isnull(volte.[3-3.5 NB],0) +isnull(volte.[3.5-4 NB],0)+ isnull(volte.[4-4.5 NB],0)+ isnull(volte.[4.5-5 NB],0))  as [MOS ALL Samples NB]

		,sum(isnull(volte.[1-1.5 NB],0)+ isnull(volte.[1.5-2 NB],0)+ isnull(volte.[2-2.5 NB],0)) as [MOS Below 2.5 Samples NB]
		,sum(isnull(volte.[3.5-4 NB],0)+ isnull(volte.[4-4.5 NB],0)+ isnull(volte.[4.5-5 NB],0)) as [MOS Over 3.5 Samples NB],

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(volte.[MOS_Samples_Under_2.5]) as [MOS_Samples_Under_2.5],
		sum(volte.[MOS_NB_Samples_Under_2.5]) as [MOS_NB_Samples_Under_2.5],
		sum(volte.Registers+volte.Registers_NB) as [Samples_DL+UL],
		sum(volte.Registers_NB) as [Samples_DL+UL_NB],
		sum(volte.Calls_WB_Only) as [WB AMR Only],
		sum(volte.Calls_WB_Only)*sum(volte.MOS_WBOnly) as [Avg WB AMR Only],

		---------------------------------
		/*kpis nuevos añadidos para DASH*/	
		1.0*(sum(volte.mos_nb*volte.Calls_MOS_NB)) as MOS_NB_Num,
		sum(volte.Calls_MOS_NB) as MOS_NB_Den,
		1.0*sum(volte.[MOS_WBOnly]*volte.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Num],
		sum(volte.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Den],
		sum(volte.[MOS_Samples_Under_2.5]+volte.[MOS_NB_Samples_Under_2.5]) as [MOS_Overall_Samples_Under_2.5],

		-------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	from [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ] volte, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE ALL Road' else 'VOLTE ALL' end, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		else p.vf_environment end,volte.mnc,volte.meas_round,volte.Date_reporting,volte.week_reporting, volte.entidad, volte.Report_Type, volte.Aggr_Type,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype, volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	---------
	-- VOLTE 4G:
	insert into _RI_Voice_m
	select
		volte.calltype as Calltype, 
		p.codigo_ine, case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment, volte4G.mnc,volte4G.meas_round,volte4G.Date_Reporting as meas_date,volte4G.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 4G Road' 
			else 'VOLTE 4G' end as meas_Tech, 1 as info_available, volte4G.entidad as vf_entity, volte4G.Report_Type, volte4G.aggr_type,

		1.0*(sum(volte4G.[MOS_ALL]*volte4G.calls_mos)) as MOS_Num,
		sum(volte4G.calls_mos) as MOS_Samples

		--- FJLA 2016 09 13 adding mos pdf
		,sum(isnull(volte4G.[1-1.5 WB],0)) as [1_WB]
		,sum(isnull(volte4G.[1.5-2 WB],0)) as [2_WB]
		,sum(isnull(volte4G.[2-2.5 WB],0)) as [3_WB]
		,sum(isnull(volte4G.[2.5-3 WB],0)) as [4_WB]
		,sum(isnull(volte4G.[3-3.5 WB],0)) as [5_WB]
		,sum(isnull(volte4G.[3.5-4 WB],0)) as [6_WB]
		,sum(isnull(volte4G.[4-4.5 WB],0)) as [7_WB]
		,sum(isnull(volte4G.[4.5-5 WB],0)) as [8_WB]

		,sum(isnull(volte4G.[1-1.5 WB],0)+ isnull(volte4G.[1.5-2 WB],0)+ isnull(volte4G.[2-2.5 WB],0)+ isnull(volte4G.[2.5-3 WB],0) +
		 isnull(volte4G.[3-3.5 WB],0) +isnull(volte4G.[3.5-4 WB],0)+ isnull(volte4G.[4-4.5 WB],0)+ isnull(volte4G.[4.5-5 WB],0))  as [MOS ALL Samples WB]

		,sum(isnull(volte4G.[1-1.5 WB],0)+ isnull(volte4G.[1.5-2 WB],0)+ isnull(volte4G.[2-2.5 WB],0)) as [MOS Below 2.5 Samples WB] 
		,sum(isnull(volte4G.[3.5-4 WB],0)+ isnull(volte4G.[4-4.5 WB],0)+ isnull(volte4G.[4.5-5 WB],0)) as [MOS Over 3.5 Samples WB] 

		,sum(isnull(volte4G.[1-1.5 NB],0)) as [1_NB]
		,sum(isnull(volte4G.[1.5-2 NB],0)) as [2_NB]
		,sum(isnull(volte4G.[2-2.5 NB],0)) as [3_NB]
		,sum(isnull(volte4G.[2.5-3 NB],0)) as [4_NB]
		,sum(isnull(volte4G.[3-3.5 NB],0)) as [5_NB]
		,sum(isnull(volte4G.[3.5-4 NB],0)) as [6_NB]
		,sum(isnull(volte4G.[4-4.5 NB],0)) as [7_NB]
		,sum(isnull(volte4G.[4.5-5 NB],0)) as [8_NB]

		,sum(isnull(volte4G.[1-1.5 NB],0)+ isnull(volte4G.[1.5-2 NB],0)+ isnull(volte4G.[2-2.5 NB],0)+ isnull(volte4G.[2.5-3 NB],0) +
		 isnull(volte4G.[3-3.5 NB],0) +isnull(volte4G.[3.5-4 NB],0)+ isnull(volte4G.[4-4.5 NB],0)+ isnull(volte4G.[4.5-5 NB],0))  as [MOS ALL Samples NB]

		,sum(isnull(volte4G.[1-1.5 NB],0)+ isnull(volte4G.[1.5-2 NB],0)+ isnull(volte4G.[2-2.5 NB],0)) as [MOS Below 2.5 Samples NB]
		,sum(isnull(volte4G.[3.5-4 NB],0)+ isnull(volte4G.[4-4.5 NB],0)+ isnull(volte4G.[4.5-5 NB],0)) as [MOS Over 3.5 Samples NB],

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(volte4G.[MOS_Samples_Under_2.5]) as [MOS_Samples_Under_2.5],
		sum(volte4G.[MOS_NB_Samples_Under_2.5]) as [MOS_NB_Samples_Under_2.5],
		sum(volte4G.Registers+volte4G.Registers_NB) as [Samples_DL+UL],
		sum(volte4G.Registers_NB) as [Samples_DL+UL_NB],
		sum(volte4G.Calls_WB_Only) as [WB AMR Only],
		sum(volte4G.Calls_WB_Only)*sum(volte4G.MOS_WBOnly) as [Avg WB AMR Only],

		---------------------------------
		/*kpis nuevos añadidos para DASH*/	
		1.0*(sum(volte4G.mos_nb*volte4G.Calls_MOS_NB)) as MOS_NB_Num,
		sum(volte4G.Calls_MOS_NB) as MOS_NB_Den,
		1.0*sum(volte4G.[MOS_WBOnly]*volte4G.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Num],
		sum(volte4G.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Den],
		sum(volte4G.[MOS_Samples_Under_2.5]+volte4G.[MOS_NB_Samples_Under_2.5]) as [MOS_Overall_Samples_Under_2.5],

		-------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	from [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ] volte
			LEFT OUTER JOIN [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ_4G] volte4G on (isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')=isnull(volte4G.parcel,'0.00000 Long, 0.00000 Lat') and volte.mnc=volte4G.mnc and volte.Date_Reporting=volte4G.Date_Reporting and volte.entidad=volte4G.entidad and volte.Aggr_Type=volte4G.Aggr_Type and volte.Report_Type=volte4G.Report_Type and volte.meas_round=volte4G.meas_round) 
		, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 4G Road' else 'VOLTE 4G' end,
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		else p.vf_environment end, volte4G.mnc,volte4G.meas_round,volte4G.Date_reporting,volte4G.week_reporting, volte4G.entidad, volte4G.Report_Type, volte4G.Aggr_Type,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype,	volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	---------
	-- VOLTE RealVolte:
	insert into _RI_Voice_m
	select 
		volte.calltype as Calltype,
		p.codigo_ine, case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment, volteRV.mnc,volteRV.meas_round,volteRV.Date_Reporting as meas_date,volteRV.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE RealVOLTE Road' 
			else 'VOLTE RealVOLTE' end as meas_Tech, 1 as info_available, volteRV.entidad as vf_entity, volteRV.Report_Type, volteRV.aggr_type,

		1.0*(sum(volteRV.[MOS_ALL]*volteRV.calls_mos)) as MOS_Num,
		sum(volteRV.calls_mos) as MOS_Samples

		--- FJLA 2016 09 13 adding mos pdf
		,sum(isnull(volteRV.[1-1.5 WB],0)) as [1_WB]
		,sum(isnull(volteRV.[1.5-2 WB],0)) as [2_WB]
		,sum(isnull(volteRV.[2-2.5 WB],0)) as [3_WB]
		,sum(isnull(volteRV.[2.5-3 WB],0)) as [4_WB]
		,sum(isnull(volteRV.[3-3.5 WB],0)) as [5_WB]
		,sum(isnull(volteRV.[3.5-4 WB],0)) as [6_WB]
		,sum(isnull(volteRV.[4-4.5 WB],0)) as [7_WB]
		,sum(isnull(volteRV.[4.5-5 WB],0)) as [8_WB]

		,sum(isnull(volteRV.[1-1.5 WB],0)+ isnull(volteRV.[1.5-2 WB],0)+ isnull(volteRV.[2-2.5 WB],0)+ isnull(volteRV.[2.5-3 WB],0) +
		 isnull(volteRV.[3-3.5 WB],0) +isnull(volteRV.[3.5-4 WB],0)+ isnull(volteRV.[4-4.5 WB],0)+ isnull(volteRV.[4.5-5 WB],0))  as [MOS ALL Samples WB]

		,sum(isnull(volteRV.[1-1.5 WB],0)+ isnull(volteRV.[1.5-2 WB],0)+ isnull(volteRV.[2-2.5 WB],0)) as [MOS Below 2.5 Samples WB] 
		,sum(isnull(volteRV.[3.5-4 WB],0)+ isnull(volteRV.[4-4.5 WB],0)+ isnull(volteRV.[4.5-5 WB],0)) as [MOS Over 3.5 Samples WB] 

		,sum(isnull(volteRV.[1-1.5 NB],0)) as [1_NB]
		,sum(isnull(volteRV.[1.5-2 NB],0)) as [2_NB]
		,sum(isnull(volteRV.[2-2.5 NB],0)) as [3_NB]
		,sum(isnull(volteRV.[2.5-3 NB],0)) as [4_NB]
		,sum(isnull(volteRV.[3-3.5 NB],0)) as [5_NB]
		,sum(isnull(volteRV.[3.5-4 NB],0)) as [6_NB]
		,sum(isnull(volteRV.[4-4.5 NB],0)) as [7_NB]
		,sum(isnull(volteRV.[4.5-5 NB],0)) as [8_NB]

		,sum(isnull(volteRV.[1-1.5 NB],0)+ isnull(volteRV.[1.5-2 NB],0)+ isnull(volteRV.[2-2.5 NB],0)+ isnull(volteRV.[2.5-3 NB],0) +
		 isnull(volteRV.[3-3.5 NB],0) +isnull(volteRV.[3.5-4 NB],0)+ isnull(volteRV.[4-4.5 NB],0)+ isnull(volteRV.[4.5-5 NB],0))  as [MOS ALL Samples NB]

		,sum(isnull(volteRV.[1-1.5 NB],0)+ isnull(volteRV.[1.5-2 NB],0)+ isnull(volteRV.[2-2.5 NB],0)) as [MOS Below 2.5 Samples NB]
		,sum(isnull(volteRV.[3.5-4 NB],0)+ isnull(volteRV.[4-4.5 NB],0)+ isnull(volteRV.[4.5-5 NB],0)) as [MOS Over 3.5 Samples NB],

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(volteRV.[MOS_Samples_Under_2.5]) as [MOS_Samples_Under_2.5],
		sum(volteRV.[MOS_NB_Samples_Under_2.5]) as [MOS_NB_Samples_Under_2.5],
		sum(volteRV.Registers+volteRV.Registers_NB) as [Samples_DL+UL],
		sum(volteRV.Registers_NB) as [Samples_DL+UL_NB],
		sum(volteRV.Calls_WB_Only) as [WB AMR Only],
		sum(volteRV.Calls_WB_Only)*sum(volteRV.MOS_WBOnly) as [Avg WB AMR Only],

		---------------------------------
		/*kpis nuevos añadidos para DASH*/	
		1.0*(sum(volteRV.mos_nb*volteRV.Calls_MOS_NB)) as MOS_NB_Num,
		sum(volteRV.Calls_MOS_NB) as MOS_NB_Den,
		1.0*sum(volteRV.[MOS_WBOnly]*volteRV.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Num],
		sum(volteRV.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Den],
		sum(volteRV.[MOS_Samples_Under_2.5]+volteRV.[MOS_NB_Samples_Under_2.5]) as [MOS_Overall_Samples_Under_2.5],

		-------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	from	[AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ] volte
				LEFT OUTER JOIN [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ_VOLTE] volteRV on (isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')=isnull(volteRv.parcel,'0.00000 Long, 0.00000 Lat') and volte.mnc=volteRv.mnc and volte.Date_Reporting=volteRv.Date_Reporting and volte.entidad=volteRv.entidad and volte.Aggr_Type=volteRv.Aggr_Type and volte.Report_Type=volteRv.Report_Type and volte.meas_round=volteRv.meas_round) 
			, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE RealVOLTE Road' else 'VOLTE RealVOLTE' end, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		else p.vf_environment end,volteRV.mnc,volteRV.meas_round,volteRV.Date_reporting,volteRV.week_reporting, volteRV.entidad, volteRV.Report_Type, volteRV.Aggr_Type,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype, volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	---------
	-- VOLTE 3G:
	insert into _RI_Voice_m
	select
		volte.calltype as Calltype, 
		p.codigo_ine,
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment,volte3G.mnc,volte3G.meas_round,volte3G.Date_Reporting as meas_date,volte3G.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 3G Road' 
			else 'VOLTE 3G' end as meas_Tech, 1 as info_available, volte3G.entidad as vf_entity, volte3G.Report_Type, volte3G.aggr_type,

		1.0*(sum(volte3G.[MOS_ALL]*volte3G.calls_mos)) as MOS_Num,
		sum(volte3G.calls_mos) as MOS_Samples

		--- FJLA 2016 09 13 adding mos pdf
		,sum(isnull(volte3G.[1-1.5 WB],0)) as [1_WB]
		,sum(isnull(volte3G.[1.5-2 WB],0)) as [2_WB]
		,sum(isnull(volte3G.[2-2.5 WB],0)) as [3_WB]
		,sum(isnull(volte3G.[2.5-3 WB],0)) as [4_WB]
		,sum(isnull(volte3G.[3-3.5 WB],0)) as [5_WB]
		,sum(isnull(volte3G.[3.5-4 WB],0)) as [6_WB]
		,sum(isnull(volte3G.[4-4.5 WB],0)) as [7_WB]
		,sum(isnull(volte3G.[4.5-5 WB],0)) as [8_WB]

		,sum(isnull(volte3G.[1-1.5 WB],0)+ isnull(volte3G.[1.5-2 WB],0)+ isnull(volte3G.[2-2.5 WB],0)+ isnull(volte3G.[2.5-3 WB],0) +
		 isnull(volte3G.[3-3.5 WB],0) +isnull(volte3G.[3.5-4 WB],0)+ isnull(volte3G.[4-4.5 WB],0)+ isnull(volte3G.[4.5-5 WB],0))  as [MOS ALL Samples WB]

		,sum(isnull(volte3G.[1-1.5 WB],0)+ isnull(volte3G.[1.5-2 WB],0)+ isnull(volte3G.[2-2.5 WB],0)) as [MOS Below 2.5 Samples WB] 
		,sum(isnull(volte3G.[3.5-4 WB],0)+ isnull(volte3G.[4-4.5 WB],0)+ isnull(volte3G.[4.5-5 WB],0)) as [MOS Over 3.5 Samples WB] 

		,sum(isnull(volte3G.[1-1.5 NB],0)) as [1_NB]
		,sum(isnull(volte3G.[1.5-2 NB],0)) as [2_NB]
		,sum(isnull(volte3G.[2-2.5 NB],0)) as [3_NB]
		,sum(isnull(volte3G.[2.5-3 NB],0)) as [4_NB]
		,sum(isnull(volte3G.[3-3.5 NB],0)) as [5_NB]
		,sum(isnull(volte3G.[3.5-4 NB],0)) as [6_NB]
		,sum(isnull(volte3G.[4-4.5 NB],0)) as [7_NB]
		,sum(isnull(volte3G.[4.5-5 NB],0)) as [8_NB]

		,sum(isnull(volte3G.[1-1.5 NB],0)+ isnull(volte3G.[1.5-2 NB],0)+ isnull(volte3G.[2-2.5 NB],0)+ isnull(volte3G.[2.5-3 NB],0) +
		 isnull(volte3G.[3-3.5 NB],0) +isnull(volte3G.[3.5-4 NB],0)+ isnull(volte3G.[4-4.5 NB],0)+ isnull(volte3G.[4.5-5 NB],0))  as [MOS ALL Samples NB]

		,sum(isnull(volte3G.[1-1.5 NB],0)+ isnull(volte3G.[1.5-2 NB],0)+ isnull(volte3G.[2-2.5 NB],0)) as [MOS Below 2.5 Samples NB]
		,sum(isnull(volte3G.[3.5-4 NB],0)+ isnull(volte3G.[4-4.5 NB],0)+ isnull(volte3G.[4.5-5 NB],0)) as [MOS Over 3.5 Samples NB],

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(volte3G.[MOS_Samples_Under_2.5]) as [MOS_Samples_Under_2.5],
		sum(volte3G.[MOS_NB_Samples_Under_2.5]) as [MOS_NB_Samples_Under_2.5],
		sum(volte3G.Registers+volte3G.Registers_NB) as [Samples_DL+UL],
		sum(volte3G.Registers_NB) as [Samples_DL+UL_NB],
		sum(volte3G.Calls_WB_Only) as [WB AMR Only],
		sum(volte3G.Calls_WB_Only)*sum(volte3G.MOS_WBOnly) as [Avg WB AMR Only],

		---------------------------------
		/*kpis nuevos añadidos para DASH*/	
		1.0*(sum(volte3G.mos_nb*volte3G.Calls_MOS_NB)) as MOS_NB_Num,
		sum(volte3G.Calls_MOS_NB) as MOS_NB_Den,
		1.0*sum(volte3G.[MOS_WBOnly]*volte3G.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Num],
		sum(volte3G.[Calls_AVG_WB_ONLY]) as [WB_AMR_Only_Den],
		sum(volte3G.[MOS_Samples_Under_2.5]+volte3G.[MOS_NB_Samples_Under_2.5]) as [MOS_Overall_Samples_Under_2.5],

		-------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	from 	[AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ] volte
				LEFT OUTER JOIN [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_PESQ_3G] volte3G  on (isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')=isnull(volte3G.parcel,'0.00000 Long, 0.00000 Lat') and volte.mnc=volte3G.mnc and volte.Date_Reporting=volte3G.Date_Reporting and volte.entidad=volte3G.entidad and volte.Aggr_Type=volte3G.Aggr_Type and volte.Report_Type=volte3G.Report_Type and volte.meas_round=volte3G.meas_round) 
			, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 3G Road' else 'VOLTE 3G' end, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		else p.vf_environment end, volte3G.mnc,volte3G.meas_round,volte3G.Date_reporting,volte3G.week_reporting, volte3G.entidad, volte3G.Report_Type, volte3G.Aggr_Type,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 2.3 MOS VOLTE - ALL, 4G, RealVOLTE, 3G', getdate()


	------------------------------------------------------------------------------
	-- 3. CST 3G, 4G y Road and 4GOnly y Road 4GOnly 
	--	  Añadido info VOLTE (aLL, 4G, RealVOLTE, 3G)
	------------------------------------------------------------------------------ 
	print '3.1 CST 3G, 4G y Road'
	-----------	
	-- 3G:	
	insert into _RI_Voice_cst
	select
		cst.calltype as Calltype, 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week, 
	   '3G' as meas_Tech, 1 as info_available, entidad as vf_entity, Report_Type, aggr_type,
  
		--0.001*(1000.0*SUM(CST.[CST_MOMT_Alerting]*(CST.[MO_CallType]+CST.[MT_CallType]))) as CST_ALERTING_NUM,
		--0.001*(1000.0*SUM(CST.[CST_MOMT_Connect]*(CST.[MO_CallType]+CST.[MT_CallType]))) as CST_CONNECT_NUM,

		--20170710 : @MDM: Cambio en el cálculo del cálculo del CST considerando el mismo campo en el numerador y el denominador para el ponderado
		0.001*(1000.0*SUM(CST.[CST_MOMT_Alerting]*(CST.[Calls_AVG_ALERT_MO]+CST.[Calls_AVG_ALERT_MT]))) as CST_ALERTING_NUM,
		0.001*(1000.0*SUM(CST.[CST_MOMT_Connect]*(CST.[Calls_AVG_CONNECT_MO]+CST.[Calls_AVG_CONNECT_MT]))) as CST_CONNECT_NUM,
		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(cst.[Calls_AVG_ALERT_MO]) as CST_MO_AL_samples,
		sum(cst.[Calls_AVG_ALERT_MT]) as CST_MT_AL_samples,
		sum(cst.[Calls_AVG_CONNECT_MO]) as CST_MO_CO_Samples,
		sum(cst.[Calls_AVG_CONNECT_MT]) as CST_MT_CO_Samples,

		0.001*(1000.0*SUM(CST.[CST_MO_Alerting]*CST.[Calls_AVG_ALERT_MO])) as CST_MO_AL_NUM,
		0.001*(1000.0*SUM(CST.[CST_MT_Alerting]*CST.[Calls_AVG_ALERT_MT])) as CST_MT_AL_NUM,
		0.001*(1000.0*SUM(CST.[CST_MO_Connect]*CST.[Calls_AVG_CONNECT_MO])) as CST_MO_CO_NUM,
		0.001*(1000.0*SUM(CST.[CST_MT_Connect]*CST.[Calls_AVG_CONNECT_MT])) as CST_MT_CO_NUM,

		---------------------------------
		-- Rangos MO ALERTING:
		sum(cst.[ 0-0.5 MO_Alert]) as [1_MO_A],	sum(cst.[ 0.5-1 MO_Alert]) as [2_MO_A],		sum(cst.[ 1-1.5 MO_Alert]) as [3_MO_A],
		sum(cst.[ 1.5-2 MO_Alert]) as [4_MO_A],	sum(cst.[ 2-2.5 MO_Alert]) as [5_MO_A],		sum(cst.[ 2.5-3 MO_Alert]) as [6_MO_A],
		sum(cst.[ 3-3.5 MO_Alert]) as [7_MO_A],	sum(cst.[ 3.5-4 MO_Alert]) as [8_MO_A],		sum(cst.[ 4-4.5 MO_Alert]) as [9_MO_A],
		sum(cst.[ 4.5-5 MO_Alert]) as [10_MO_A],	sum(cst.[ 5-5.5 MO_Alert]) as [11_MO_A],		sum(cst.[ 5.5-6 MO_Alert]) as [12_MO_A],
		sum(cst.[ 6-6.5 MO_Alert]) as [13_MO_A],	sum(cst.[ 6.5-7 MO_Alert]) as [14_MO_A],		sum(cst.[ 7-7.5 MO_Alert]) as [15_MO_A],
		sum(cst.[ 7.5-8 MO_Alert]) as [16_MO_A],	sum(cst.[ 8-8.5 MO_Alert]) as [17_MO_A],		sum(cst.[ 8.5-9 MO_Alert]) as [18_MO_A],
		sum(cst.[ 9-9.5 MO_Alert]) as [19_MO_A],	sum(cst.[ 9.5-10 MO_Alert]) as [20_MO_A],		sum(cst.[ 10-10.5 MO_Alert]) as [21_MO_A],
		sum(cst.[ 10.5-11 MO_Alert]) as [22_MO_A],	sum(cst.[ 11-11.5 MO_Alert]) as [23_MO_A],	sum(cst.[ 11.5-12 MO_Alert]) as [24_MO_A],
		sum(cst.[ 12-12.5 MO_Alert]) as [25_MO_A],	sum(cst.[ 12.5-13 MO_Alert]) as [26_MO_A],	sum(cst.[ 13-13.5 MO_Alert]) as [27_MO_A],
		sum(cst.[ 13.5-14 MO_Alert]) as [28_MO_A],	sum(cst.[ 14-14.5 MO_Alert]) as [29_MO_A],	sum(cst.[ 14.5-15 MO_Alert]) as [30_MO_A],
		sum(cst.[ 15-15.5 MO_Alert]) as [31_MO_A],	sum(cst.[ 15.5-16 MO_Alert]) as [32_MO_A],	sum(cst.[ 16-16.5 MO_Alert]) as [33_MO_A],
		sum(cst.[ 16.5-17 MO_Alert]) as [34_MO_A],	sum(cst.[ 17-17.5 MO_Alert]) as [35_MO_A],	sum(cst.[ 17.5-18 MO_Alert]) as [36_MO_A],
		sum(cst.[ 18-18.5 MO_Alert]) as [37_MO_A],	sum(cst.[ 18.5-19 MO_Alert]) as [38_MO_A],	sum(cst.[ 19-19.5 MO_Alert]) as [39_MO_A],
		sum(cst.[ 19.5-20 MO_Alert]) as [40_MO_A],	sum(cst.[ >20 MO_Alert]) as [41_MO_A],

		---------------------------------
		-- Rangos MT ALERTING:
		sum(cst.[ 0-0.5 MT_Alert]) as [1_MT_A],	sum(cst.[ 0.5-1 MT_Alert]) as [2_MT_A],		sum(cst.[ 1-1.5 MT_Alert]) as [3_MT_A],
		sum(cst.[ 1.5-2 MT_Alert]) as [4_MT_A],	sum(cst.[ 2-2.5 MT_Alert]) as [5_MT_A],		sum(cst.[ 2.5-3 MT_Alert]) as [6_MT_A],
		sum(cst.[ 3-3.5 MT_Alert]) as [7_MT_A],	sum(cst.[ 3.5-4 MT_Alert]) as [8_MT_A],		sum(cst.[ 4-4.5 MT_Alert]) as [9_MT_A],
		sum(cst.[ 4.5-5 MT_Alert]) as [10_MT_A],	sum(cst.[ 5-5.5 MT_Alert]) as [11_MT_A],		sum(cst.[ 5.5-6 MT_Alert]) as [12_MT_A],
		sum(cst.[ 6-6.5 MT_Alert]) as [13_MT_A],	sum(cst.[ 6.5-7 MT_Alert]) as [14_MT_A],		sum(cst.[ 7-7.5 MT_Alert]) as [15_MT_A],
		sum(cst.[ 7.5-8 MT_Alert]) as [16_MT_A],	sum(cst.[ 8-8.5 MT_Alert]) as [17_MT_A],		sum(cst.[ 8.5-9 MT_Alert]) as [18_MT_A],
		sum(cst.[ 9-9.5 MT_Alert]) as [19_MT_A],	sum(cst.[ 9.5-10 MT_Alert]) as [20_MT_A],		sum(cst.[ 10-10.5 MT_Alert]) as [21_MT_A],
		sum(cst.[ 10.5-11 MT_Alert]) as [22_MT_A],	sum(cst.[ 11-11.5 MT_Alert]) as [23_MT_A],	sum(cst.[ 11.5-12 MT_Alert]) as [24_MT_A],
		sum(cst.[ 12-12.5 MT_Alert]) as [25_MT_A],	sum(cst.[ 12.5-13 MT_Alert]) as [26_MT_A],	sum(cst.[ 13-13.5 MT_Alert]) as [27_MT_A],
		sum(cst.[ 13.5-14 MT_Alert]) as [28_MT_A],	sum(cst.[ 14-14.5 MT_Alert]) as [29_MT_A],	sum(cst.[ 14.5-15 MT_Alert]) as [30_MT_A],
		sum(cst.[ 15-15.5 MT_Alert]) as [31_MT_A],	sum(cst.[ 15.5-16 MT_Alert]) as [32_MT_A],	sum(cst.[ 16-16.5 MT_Alert]) as [33_MT_A],
		sum(cst.[ 16.5-17 MT_Alert]) as [34_MT_A],	sum(cst.[ 17-17.5 MT_Alert]) as [35_MT_A],	sum(cst.[ 17.5-18 MT_Alert]) as [36_MT_A],
		sum(cst.[ 18-18.5 MT_Alert]) as [37_MT_A],	sum(cst.[ 18.5-19 MT_Alert]) as [38_MT_A],	sum(cst.[ 19-19.5 MT_Alert]) as [39_MT_A],
		sum(cst.[ 19.5-20 MT_Alert]) as [40_MT_A],	sum(cst.[ >20 MT_Alert]) as [41_MT_A],

		---------------------------------
		-- Rangos MOMT ALERTING:
		sum(cst.[ 0-0.5 MOMT_Alert]) as [1_MOMT_A],	sum(cst.[ 0.5-1 MOMT_Alert]) as [2_MOMT_A],	sum(cst.[ 1-1.5 MOMT_Alert]) as [3_MOMT_A],
		sum(cst.[ 1.5-2 MOMT_Alert]) as [4_MOMT_A],	sum(cst.[ 2-2.5 MOMT_Alert]) as [5_MOMT_A],	sum(cst.[ 2.5-3 MOMT_Alert]) as [6_MOMT_A],
		sum(cst.[ 3-3.5 MOMT_Alert]) as [7_MOMT_A],	sum(cst.[ 3.5-4 MOMT_Alert]) as [8_MOMT_A],	sum(cst.[ 4-4.5 MOMT_Alert]) as [9_MOMT_A],
		sum(cst.[ 4.5-5 MOMT_Alert]) as [10_MOMT_A],	sum(cst.[ 5-5.5 MOMT_Alert]) as [11_MOMT_A],	sum(cst.[ 5.5-6 MOMT_Alert]) as [12_MOMT_A],
		sum(cst.[ 6-6.5 MOMT_Alert]) as [13_MOMT_A],	sum(cst.[ 6.5-7 MOMT_Alert]) as [14_MOMT_A],	sum(cst.[ 7-7.5 MOMT_Alert]) as [15_MOMT_A],
		sum(cst.[ 7.5-8 MOMT_Alert]) as [16_MOMT_A],	sum(cst.[ 8-8.5 MOMT_Alert]) as [17_MOMT_A],	sum(cst.[ 8.5-9 MOMT_Alert]) as [18_MOMT_A],
		sum(cst.[ 9-9.5 MOMT_Alert]) as [19_MOMT_A],	sum(cst.[ 9.5-10 MOMT_Alert]) as [20_MOMT_A],	sum(cst.[ 10-10.5 MOMT_Alert]) as [21_MOMT_A],
		sum(cst.[ 10.5-11 MOMT_Alert]) as [22_MOMT_A],	sum(cst.[ 11-11.5 MOMT_Alert]) as [23_MOMT_A],	sum(cst.[ 11.5-12 MOMT_Alert]) as [24_MOMT_A],
		sum(cst.[ 12-12.5 MOMT_Alert]) as [25_MOMT_A],	sum(cst.[ 12.5-13 MOMT_Alert]) as [26_MOMT_A],	sum(cst.[ 13-13.5 MOMT_Alert]) as [27_MOMT_A],
		sum(cst.[ 13.5-14 MOMT_Alert]) as [28_MOMT_A],	sum(cst.[ 14-14.5 MOMT_Alert]) as [29_MOMT_A],	sum(cst.[ 14.5-15 MOMT_Alert]) as [30_MOMT_A],
		sum(cst.[ 15-15.5 MOMT_Alert]) as [31_MOMT_A],	sum(cst.[ 15.5-16 MOMT_Alert]) as [32_MOMT_A],	sum(cst.[ 16-16.5 MOMT_Alert]) as [33_MOMT_A],
		sum(cst.[ 16.5-17 MOMT_Alert]) as [34_MOMT_A],	sum(cst.[ 17-17.5 MOMT_Alert]) as [35_MOMT_A],	sum(cst.[ 17.5-18 MOMT_Alert]) as [36_MOMT_A],
		sum(cst.[ 18-18.5 MOMT_Alert]) as [37_MOMT_A],	sum(cst.[ 18.5-19 MOMT_Alert]) as [38_MOMT_A],	sum(cst.[ 19-19.5 MOMT_Alert]) as [39_MOMT_A],
		sum(cst.[ 19.5-20 MOMT_Alert]) as [40_MOMT_A],	sum(cst.[ >20 MOMT_Alert]) as [41_MOMT_A],

		---------------------------------
		-- Rangos MO CONNECT:
		sum(cst.[ 0-0.5 MO_Conn]) as [1_MO_C],	sum(cst.[ 0.5-1 MO_Conn]) as [2_MO_C],	sum(cst.[ 1-1.5 MO_Conn]) as [3_MO_C],
		sum(cst.[ 1.5-2 MO_Conn]) as [4_MO_C],	sum(cst.[ 2-2.5 MO_Conn]) as [5_MO_C],	sum(cst.[ 2.5-3 MO_Conn]) as [6_MO_C],	
		sum(cst.[ 3-3.5 MO_Conn]) as [7_MO_C],	sum(cst.[ 3.5-4 MO_Conn]) as [8_MO_C],	sum(cst.[ 4-4.5 MO_Conn]) as [9_MO_C],
		sum(cst.[ 4.5-5 MO_Conn]) as [10_MO_C],	sum(cst.[ 5-5.5 MO_Conn]) as [11_MO_C],	sum(cst.[ 5.5-6 MO_Conn]) as [12_MO_C],
		sum(cst.[ 6-6.5 MO_Conn]) as [13_MO_C],	sum(cst.[ 6.5-7 MO_Conn]) as [14_MO_C],	sum(cst.[ 7-7.5 MO_Conn]) as [15_MO_C],
		sum(cst.[ 7.5-8 MO_Conn]) as [16_MO_C],	sum(cst.[ 8-8.5 MO_Conn]) as [17_MO_C],	sum(cst.[ 8.5-9 MO_Conn]) as [18_MO_C],
		sum(cst.[ 9-9.5 MO_Conn]) as [19_MO_C],	sum(cst.[ 9.5-10 MO_Conn]) as [20_MO_C],	sum(cst.[ 10-10.5 MO_Conn]) as [21_MO_C],
		sum(cst.[ 10.5-11 MO_Conn]) as [22_MO_C],	sum(cst.[ 11-11.5 MO_Conn]) as [23_MO_C],	sum(cst.[ 11.5-12 MO_Conn]) as [24_MO_C],
		sum(cst.[ 12-12.5 MO_Conn]) as [25_MO_C],	sum(cst.[ 12.5-13 MO_Conn]) as [26_MO_C],	sum(cst.[ 13-13.5 MO_Conn]) as [27_MO_C],
		sum(cst.[ 13.5-14 MO_Conn]) as [28_MO_C],	sum(cst.[ 14-14.5 MO_Conn]) as [29_MO_C],	sum(cst.[ 14.5-15 MO_Conn]) as [30_MO_C],
		sum(cst.[ 15-15.5 MO_Conn]) as [31_MO_C],	sum(cst.[ 15.5-16 MO_Conn]) as [32_MO_C],	sum(cst.[ 16-16.5 MO_Conn]) as [33_MO_C],
		sum(cst.[ 16.5-17 MO_Conn]) as [34_MO_C],	sum(cst.[ 17-17.5 MO_Conn]) as [35_MO_C],	sum(cst.[ 17.5-18 MO_Conn]) as [36_MO_C],
		sum(cst.[ 18-18.5 MO_Conn]) as [37_MO_C],	sum(cst.[ 18.5-19 MO_Conn]) as [38_MO_C],	sum(cst.[ 19-19.5 MO_Conn]) as [39_MO_C],
		sum(cst.[ 19.5-20 MO_Conn]) as [40_MO_C],	sum(cst.[ >20 MO_Conn]) as [41_MO_C],

		---------------------------------
		-- Rangos MT CONNECT:
		sum(cst.[ 0-0.5 MT_Conn]) as [1_MT_C],	sum(cst.[ 0.5-1 MT_Conn]) as [2_MT_C],	sum(cst.[ 1-1.5 MT_Conn]) as [3_MT_C],
		sum(cst.[ 1.5-2 MT_Conn]) as [4_MT_C],	sum(cst.[ 2-2.5 MT_Conn]) as [5_MT_C],	sum(cst.[ 2.5-3 MT_Conn]) as [6_MT_C],
		sum(cst.[ 3-3.5 MT_Conn]) as [7_MT_C],	sum(cst.[ 3.5-4 MT_Conn]) as [8_MT_C],	sum(cst.[ 4-4.5 MT_Conn]) as [9_MT_C],
		sum(cst.[ 4.5-5 MT_Conn]) as [10_MT_C],	sum(cst.[ 5-5.5 MT_Conn]) as [11_MT_C],	sum(cst.[ 5.5-6 MT_Conn]) as [12_MT_C],
		sum(cst.[ 6-6.5 MT_Conn]) as [13_MT_C],	sum(cst.[ 6.5-7 MT_Conn]) as [14_MT_C],	sum(cst.[ 7-7.5 MT_Conn]) as [15_MT_C],
		sum(cst.[ 7.5-8 MT_Conn]) as [16_MT_C],	sum(cst.[ 8-8.5 MT_Conn]) as [17_MT_C],	sum(cst.[ 8.5-9 MT_Conn]) as [18_MT_C],
		sum(cst.[ 9-9.5 MT_Conn]) as [19_MT_C],	sum(cst.[ 9.5-10 MT_Conn]) as [20_MT_C],	sum(cst.[ 10-10.5 MT_Conn]) as [21_MT_C],
		sum(cst.[ 10.5-11 MT_Conn]) as [22_MT_C],	sum(cst.[ 11-11.5 MT_Conn]) as [23_MT_C],	sum(cst.[ 11.5-12 MT_Conn]) as [24_MT_C],
		sum(cst.[ 12-12.5 MT_Conn]) as [25_MT_C],	sum(cst.[ 12.5-13 MT_Conn]) as [26_MT_C],	sum(cst.[ 13-13.5 MT_Conn]) as [27_MT_C],
		sum(cst.[ 13.5-14 MT_Conn]) as [28_MT_C],	sum(cst.[ 14-14.5 MT_Conn]) as [29_MT_C],	sum(cst.[ 14.5-15 MT_Conn]) as [30_MT_C],
		sum(cst.[ 15-15.5 MT_Conn]) as [31_MT_C],	sum(cst.[ 15.5-16 MT_Conn]) as [32_MT_C],	sum(cst.[ 16-16.5 MT_Conn]) as [33_MT_C],
		sum(cst.[ 16.5-17 MT_Conn]) as [34_MT_C],	sum(cst.[ 17-17.5 MT_Conn]) as [35_MT_C],	sum(cst.[ 17.5-18 MT_Conn]) as [36_MT_C],
		sum(cst.[ 18-18.5 MT_Conn]) as [37_MT_C],	sum(cst.[ 18.5-19 MT_Conn]) as [38_MT_C],	sum(cst.[ 19-19.5 MT_Conn]) as [39_MT_C],
		sum(cst.[ 19.5-20 MT_Conn]) as [40_MT_C],	sum(cst.[ >20 MT_Conn]) as [41_MT_C],

		---------------------------------
		-- Rangos MOMT CONNECT:
		sum(cst.[ 0-0.5 MOMT_Conn]) as [1_MOMT_C],	sum(cst.[ 0.5-1 MOMT_Conn]) as [2_MOMT_C],	sum(cst.[ 1-1.5 MOMT_Conn]) as [3_MOMT_C],
		sum(cst.[ 1.5-2 MOMT_Conn]) as [4_MOMT_C],	sum(cst.[ 2-2.5 MOMT_Conn]) as [5_MOMT_C],	sum(cst.[ 2.5-3 MOMT_Conn]) as [6_MOMT_C],
		sum(cst.[ 3-3.5 MOMT_Conn]) as [7_MOMT_C],	sum(cst.[ 3.5-4 MOMT_Conn]) as [8_MOMT_C],	sum(cst.[ 4-4.5 MOMT_Conn]) as [9_MOMT_C],
		sum(cst.[ 4.5-5 MOMT_Conn]) as [10_MOMT_C],	sum(cst.[ 5-5.5 MOMT_Conn]) as [11_MOMT_C],	sum(cst.[ 5.5-6 MOMT_Conn]) as [12_MOMT_C],
		sum(cst.[ 6-6.5 MOMT_Conn]) as [13_MOMT_C],	sum(cst.[ 6.5-7 MOMT_Conn]) as [14_MOMT_C],	sum(cst.[ 7-7.5 MOMT_Conn]) as [15_MOMT_C],
		sum(cst.[ 7.5-8 MOMT_Conn]) as [16_MOMT_C],	sum(cst.[ 8-8.5 MOMT_Conn]) as [17_MOMT_C],	sum(cst.[ 8.5-9 MOMT_Conn]) as [18_MOMT_C],
		sum(cst.[ 9-9.5 MOMT_Conn]) as [19_MOMT_C],	sum(cst.[ 9.5-10 MOMT_Conn]) as [20_MOMT_C],	sum(cst.[ 10-10.5 MOMT_Conn]) as [21_MOMT_C],
		sum(cst.[ 10.5-11 MOMT_Conn]) as [22_MOMT_C],	sum(cst.[ 11-11.5 MOMT_Conn]) as [23_MOMT_C],	sum(cst.[ 11.5-12 MOMT_Conn]) as [24_MOMT_C],
		sum(cst.[ 12-12.5 MOMT_Conn]) as [25_MOMT_C],	sum(cst.[ 12.5-13 MOMT_Conn]) as [26_MOMT_C],	sum(cst.[ 13-13.5 MOMT_Conn]) as [27_MOMT_C],
		sum(cst.[ 13.5-14 MOMT_Conn]) as [28_MOMT_C],	sum(cst.[ 14-14.5 MOMT_Conn]) as [29_MOMT_C],	sum(cst.[ 14.5-15 MOMT_Conn]) as [30_MOMT_C],
		sum(cst.[ 15-15.5 MOMT_Conn]) as [31_MOMT_C],	sum(cst.[ 15.5-16 MOMT_Conn]) as [32_MOMT_C],	sum(cst.[ 16-16.5 MOMT_Conn]) as [33_MOMT_C],
		sum(cst.[ 16.5-17 MOMT_Conn]) as [34_MOMT_C],	sum(cst.[ 17-17.5 MOMT_Conn]) as [35_MOMT_C],	sum(cst.[ 17.5-18 MOMT_Conn]) as [36_MOMT_C],
		sum(cst.[ 18-18.5 MOMT_Conn]) as [37_MOMT_C],	sum(cst.[ 18.5-19 MOMT_Conn]) as [38_MOMT_C],	sum(cst.[ 19-19.5 MOMT_Conn]) as [39_MOMT_C],
		sum(cst.[ 19.5-20 MOMT_Conn]) as [40_MOMT_C],	sum(cst.[ >20 MOMT_Conn]) as [41_MOMT_C],

		---------------------------------
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end as Region_Road_VF,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end as Region_Road_OSP,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]

	from [AGGRVoice3G].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls] cst, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end ,mnc,meas_round,Date_Reporting,Week_Reporting,entidad, Report_Type, aggr_type
		,cst.calltype, cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]--,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end


	---------
	-- 4G:
	insert into _RI_Voice_cst
	select
		cst.calltype as Calltype, 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week, 
	   '4G' as meas_Tech, 1 as info_available, entidad as vf_entity, Report_Type, aggr_type,
    
		--0.001*(1000.0*SUM(CST.[CST_MOMT_Alerting]*(CST.[MO_CallType]+CST.[MT_CallType]))) as CST_ALERTING_NUM,
		--0.001*(1000.0*SUM(CST.[CST_MOMT_Connect]*(CST.[MO_CallType]+CST.[MT_CallType]))) as CST_CONNECT_NUM,

		--20170710 : @MDM: Cambio en el cálculo del cálculo del CST considerando el mismo campo en el numerador y el denominador para el ponderado
		0.001*(1000.0*SUM(CST.[CST_MOMT_Alerting]*(CST.[Calls_AVG_ALERT_MO]+CST.[Calls_AVG_ALERT_MT]))) as CST_ALERTING_NUM,
		0.001*(1000.0*SUM(CST.[CST_MOMT_Connect]*(CST.[Calls_AVG_CONNECT_MO]+CST.[Calls_AVG_CONNECT_MT]))) as CST_CONNECT_NUM,

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(cst.[Calls_AVG_ALERT_MO]) as CST_MO_AL_samples,
		sum(cst.[Calls_AVG_ALERT_MT]) as CST_MT_AL_samples,
		sum(cst.[Calls_AVG_CONNECT_MO]) as CST_MO_CO_Samples,
		sum(cst.[Calls_AVG_CONNECT_MT]) as CST_MT_CO_Samples,

		0.001*(1000.0*SUM(CST.[CST_MO_Alerting]*CST.[Calls_AVG_ALERT_MO])) as CST_MO_AL_NUM,
		0.001*(1000.0*SUM(CST.[CST_MT_Alerting]*CST.[Calls_AVG_ALERT_MT])) as CST_MT_AL_NUM,
		0.001*(1000.0*SUM(CST.[CST_MO_Connect]*CST.[Calls_AVG_CONNECT_MO])) as CST_MO_CO_NUM,
		0.001*(1000.0*SUM(CST.[CST_MT_Connect]*CST.[Calls_AVG_CONNECT_MT])) as CST_MT_CO_NUM,

		---------------------------------
		-- Rangos MO ALERTING:
		sum(cst.[ 0-0.5 MO_Alert]) as [1_MO_A],	sum(cst.[ 0.5-1 MO_Alert]) as [2_MO_A],		sum(cst.[ 1-1.5 MO_Alert]) as [3_MO_A],
		sum(cst.[ 1.5-2 MO_Alert]) as [4_MO_A],	sum(cst.[ 2-2.5 MO_Alert]) as [5_MO_A],		sum(cst.[ 2.5-3 MO_Alert]) as [6_MO_A],
		sum(cst.[ 3-3.5 MO_Alert]) as [7_MO_A],	sum(cst.[ 3.5-4 MO_Alert]) as [8_MO_A],		sum(cst.[ 4-4.5 MO_Alert]) as [9_MO_A],
		sum(cst.[ 4.5-5 MO_Alert]) as [10_MO_A],	sum(cst.[ 5-5.5 MO_Alert]) as [11_MO_A],		sum(cst.[ 5.5-6 MO_Alert]) as [12_MO_A],
		sum(cst.[ 6-6.5 MO_Alert]) as [13_MO_A],	sum(cst.[ 6.5-7 MO_Alert]) as [14_MO_A],		sum(cst.[ 7-7.5 MO_Alert]) as [15_MO_A],
		sum(cst.[ 7.5-8 MO_Alert]) as [16_MO_A],	sum(cst.[ 8-8.5 MO_Alert]) as [17_MO_A],		sum(cst.[ 8.5-9 MO_Alert]) as [18_MO_A],
		sum(cst.[ 9-9.5 MO_Alert]) as [19_MO_A],	sum(cst.[ 9.5-10 MO_Alert]) as [20_MO_A],		sum(cst.[ 10-10.5 MO_Alert]) as [21_MO_A],
		sum(cst.[ 10.5-11 MO_Alert]) as [22_MO_A],	sum(cst.[ 11-11.5 MO_Alert]) as [23_MO_A],	sum(cst.[ 11.5-12 MO_Alert]) as [24_MO_A],
		sum(cst.[ 12-12.5 MO_Alert]) as [25_MO_A],	sum(cst.[ 12.5-13 MO_Alert]) as [26_MO_A],	sum(cst.[ 13-13.5 MO_Alert]) as [27_MO_A],
		sum(cst.[ 13.5-14 MO_Alert]) as [28_MO_A],	sum(cst.[ 14-14.5 MO_Alert]) as [29_MO_A],	sum(cst.[ 14.5-15 MO_Alert]) as [30_MO_A],
		sum(cst.[ 15-15.5 MO_Alert]) as [31_MO_A],	sum(cst.[ 15.5-16 MO_Alert]) as [32_MO_A],	sum(cst.[ 16-16.5 MO_Alert]) as [33_MO_A],
		sum(cst.[ 16.5-17 MO_Alert]) as [34_MO_A],	sum(cst.[ 17-17.5 MO_Alert]) as [35_MO_A],	sum(cst.[ 17.5-18 MO_Alert]) as [36_MO_A],
		sum(cst.[ 18-18.5 MO_Alert]) as [37_MO_A],	sum(cst.[ 18.5-19 MO_Alert]) as [38_MO_A],	sum(cst.[ 19-19.5 MO_Alert]) as [39_MO_A],
		sum(cst.[ 19.5-20 MO_Alert]) as [40_MO_A],	sum(cst.[ >20 MO_Alert]) as [41_MO_A],
		
		---------------------------------
		-- Rangos MT ALERTING:
		sum(cst.[ 0-0.5 MT_Alert]) as [1_MT_A],	sum(cst.[ 0.5-1 MT_Alert]) as [2_MT_A],		sum(cst.[ 1-1.5 MT_Alert]) as [3_MT_A],
		sum(cst.[ 1.5-2 MT_Alert]) as [4_MT_A],	sum(cst.[ 2-2.5 MT_Alert]) as [5_MT_A],		sum(cst.[ 2.5-3 MT_Alert]) as [6_MT_A],
		sum(cst.[ 3-3.5 MT_Alert]) as [7_MT_A],	sum(cst.[ 3.5-4 MT_Alert]) as [8_MT_A],		sum(cst.[ 4-4.5 MT_Alert]) as [9_MT_A],
		sum(cst.[ 4.5-5 MT_Alert]) as [10_MT_A],	sum(cst.[ 5-5.5 MT_Alert]) as [11_MT_A],		sum(cst.[ 5.5-6 MT_Alert]) as [12_MT_A],
		sum(cst.[ 6-6.5 MT_Alert]) as [13_MT_A],	sum(cst.[ 6.5-7 MT_Alert]) as [14_MT_A],		sum(cst.[ 7-7.5 MT_Alert]) as [15_MT_A],
		sum(cst.[ 7.5-8 MT_Alert]) as [16_MT_A],	sum(cst.[ 8-8.5 MT_Alert]) as [17_MT_A],		sum(cst.[ 8.5-9 MT_Alert]) as [18_MT_A],
		sum(cst.[ 9-9.5 MT_Alert]) as [19_MT_A],	sum(cst.[ 9.5-10 MT_Alert]) as [20_MT_A],		sum(cst.[ 10-10.5 MT_Alert]) as [21_MT_A],
		sum(cst.[ 10.5-11 MT_Alert]) as [22_MT_A],	sum(cst.[ 11-11.5 MT_Alert]) as [23_MT_A],	sum(cst.[ 11.5-12 MT_Alert]) as [24_MT_A],
		sum(cst.[ 12-12.5 MT_Alert]) as [25_MT_A],	sum(cst.[ 12.5-13 MT_Alert]) as [26_MT_A],	sum(cst.[ 13-13.5 MT_Alert]) as [27_MT_A],
		sum(cst.[ 13.5-14 MT_Alert]) as [28_MT_A],	sum(cst.[ 14-14.5 MT_Alert]) as [29_MT_A],	sum(cst.[ 14.5-15 MT_Alert]) as [30_MT_A],
		sum(cst.[ 15-15.5 MT_Alert]) as [31_MT_A],	sum(cst.[ 15.5-16 MT_Alert]) as [32_MT_A],	sum(cst.[ 16-16.5 MT_Alert]) as [33_MT_A],
		sum(cst.[ 16.5-17 MT_Alert]) as [34_MT_A],	sum(cst.[ 17-17.5 MT_Alert]) as [35_MT_A],	sum(cst.[ 17.5-18 MT_Alert]) as [36_MT_A],
		sum(cst.[ 18-18.5 MT_Alert]) as [37_MT_A],	sum(cst.[ 18.5-19 MT_Alert]) as [38_MT_A],	sum(cst.[ 19-19.5 MT_Alert]) as [39_MT_A],
		sum(cst.[ 19.5-20 MT_Alert]) as [40_MT_A],	sum(cst.[ >20 MT_Alert]) as [41_MT_A],

		---------------------------------
		-- Rangos MOMT ALERTING:
		sum(cst.[ 0-0.5 MOMT_Alert]) as [1_MOMT_A],	sum(cst.[ 0.5-1 MOMT_Alert]) as [2_MOMT_A],	sum(cst.[ 1-1.5 MOMT_Alert]) as [3_MOMT_A],
		sum(cst.[ 1.5-2 MOMT_Alert]) as [4_MOMT_A],	sum(cst.[ 2-2.5 MOMT_Alert]) as [5_MOMT_A],	sum(cst.[ 2.5-3 MOMT_Alert]) as [6_MOMT_A],
		sum(cst.[ 3-3.5 MOMT_Alert]) as [7_MOMT_A],	sum(cst.[ 3.5-4 MOMT_Alert]) as [8_MOMT_A],	sum(cst.[ 4-4.5 MOMT_Alert]) as [9_MOMT_A],
		sum(cst.[ 4.5-5 MOMT_Alert]) as [10_MOMT_A],	sum(cst.[ 5-5.5 MOMT_Alert]) as [11_MOMT_A],	sum(cst.[ 5.5-6 MOMT_Alert]) as [12_MOMT_A],
		sum(cst.[ 6-6.5 MOMT_Alert]) as [13_MOMT_A],	sum(cst.[ 6.5-7 MOMT_Alert]) as [14_MOMT_A],	sum(cst.[ 7-7.5 MOMT_Alert]) as [15_MOMT_A],
		sum(cst.[ 7.5-8 MOMT_Alert]) as [16_MOMT_A],	sum(cst.[ 8-8.5 MOMT_Alert]) as [17_MOMT_A],	sum(cst.[ 8.5-9 MOMT_Alert]) as [18_MOMT_A],
		sum(cst.[ 9-9.5 MOMT_Alert]) as [19_MOMT_A],	sum(cst.[ 9.5-10 MOMT_Alert]) as [20_MOMT_A],	sum(cst.[ 10-10.5 MOMT_Alert]) as [21_MOMT_A],
		sum(cst.[ 10.5-11 MOMT_Alert]) as [22_MOMT_A],	sum(cst.[ 11-11.5 MOMT_Alert]) as [23_MOMT_A],	sum(cst.[ 11.5-12 MOMT_Alert]) as [24_MOMT_A],
		sum(cst.[ 12-12.5 MOMT_Alert]) as [25_MOMT_A],	sum(cst.[ 12.5-13 MOMT_Alert]) as [26_MOMT_A],	sum(cst.[ 13-13.5 MOMT_Alert]) as [27_MOMT_A],
		sum(cst.[ 13.5-14 MOMT_Alert]) as [28_MOMT_A],	sum(cst.[ 14-14.5 MOMT_Alert]) as [29_MOMT_A],	sum(cst.[ 14.5-15 MOMT_Alert]) as [30_MOMT_A],
		sum(cst.[ 15-15.5 MOMT_Alert]) as [31_MOMT_A],	sum(cst.[ 15.5-16 MOMT_Alert]) as [32_MOMT_A],	sum(cst.[ 16-16.5 MOMT_Alert]) as [33_MOMT_A],
		sum(cst.[ 16.5-17 MOMT_Alert]) as [34_MOMT_A],	sum(cst.[ 17-17.5 MOMT_Alert]) as [35_MOMT_A],	sum(cst.[ 17.5-18 MOMT_Alert]) as [36_MOMT_A],
		sum(cst.[ 18-18.5 MOMT_Alert]) as [37_MOMT_A],	sum(cst.[ 18.5-19 MOMT_Alert]) as [38_MOMT_A],	sum(cst.[ 19-19.5 MOMT_Alert]) as [39_MOMT_A],
		sum(cst.[ 19.5-20 MOMT_Alert]) as [40_MOMT_A],	sum(cst.[ >20 MOMT_Alert]) as [41_MOMT_A],

		---------------------------------
		-- Rangos MO CONNECT:
		sum(cst.[ 0-0.5 MO_Conn]) as [1_MO_C],	sum(cst.[ 0.5-1 MO_Conn]) as [2_MO_C],	sum(cst.[ 1-1.5 MO_Conn]) as [3_MO_C],
		sum(cst.[ 1.5-2 MO_Conn]) as [4_MO_C],	sum(cst.[ 2-2.5 MO_Conn]) as [5_MO_C],	sum(cst.[ 2.5-3 MO_Conn]) as [6_MO_C],	
		sum(cst.[ 3-3.5 MO_Conn]) as [7_MO_C],	sum(cst.[ 3.5-4 MO_Conn]) as [8_MO_C],	sum(cst.[ 4-4.5 MO_Conn]) as [9_MO_C],
		sum(cst.[ 4.5-5 MO_Conn]) as [10_MO_C],	sum(cst.[ 5-5.5 MO_Conn]) as [11_MO_C],	sum(cst.[ 5.5-6 MO_Conn]) as [12_MO_C],
		sum(cst.[ 6-6.5 MO_Conn]) as [13_MO_C],	sum(cst.[ 6.5-7 MO_Conn]) as [14_MO_C],	sum(cst.[ 7-7.5 MO_Conn]) as [15_MO_C],
		sum(cst.[ 7.5-8 MO_Conn]) as [16_MO_C],	sum(cst.[ 8-8.5 MO_Conn]) as [17_MO_C],	sum(cst.[ 8.5-9 MO_Conn]) as [18_MO_C],
		sum(cst.[ 9-9.5 MO_Conn]) as [19_MO_C],	sum(cst.[ 9.5-10 MO_Conn]) as [20_MO_C],	sum(cst.[ 10-10.5 MO_Conn]) as [21_MO_C],
		sum(cst.[ 10.5-11 MO_Conn]) as [22_MO_C],	sum(cst.[ 11-11.5 MO_Conn]) as [23_MO_C],	sum(cst.[ 11.5-12 MO_Conn]) as [24_MO_C],
		sum(cst.[ 12-12.5 MO_Conn]) as [25_MO_C],	sum(cst.[ 12.5-13 MO_Conn]) as [26_MO_C],	sum(cst.[ 13-13.5 MO_Conn]) as [27_MO_C],
		sum(cst.[ 13.5-14 MO_Conn]) as [28_MO_C],	sum(cst.[ 14-14.5 MO_Conn]) as [29_MO_C],	sum(cst.[ 14.5-15 MO_Conn]) as [30_MO_C],
		sum(cst.[ 15-15.5 MO_Conn]) as [31_MO_C],	sum(cst.[ 15.5-16 MO_Conn]) as [32_MO_C],	sum(cst.[ 16-16.5 MO_Conn]) as [33_MO_C],
		sum(cst.[ 16.5-17 MO_Conn]) as [34_MO_C],	sum(cst.[ 17-17.5 MO_Conn]) as [35_MO_C],	sum(cst.[ 17.5-18 MO_Conn]) as [36_MO_C],
		sum(cst.[ 18-18.5 MO_Conn]) as [37_MO_C],	sum(cst.[ 18.5-19 MO_Conn]) as [38_MO_C],	sum(cst.[ 19-19.5 MO_Conn]) as [39_MO_C],
		sum(cst.[ 19.5-20 MO_Conn]) as [40_MO_C],	sum(cst.[ >20 MO_Conn]) as [41_MO_C],

		---------------------------------
		-- Rangos MT CONNECT:
		sum(cst.[ 0-0.5 MT_Conn]) as [1_MT_C],	sum(cst.[ 0.5-1 MT_Conn]) as [2_MT_C],	sum(cst.[ 1-1.5 MT_Conn]) as [3_MT_C],
		sum(cst.[ 1.5-2 MT_Conn]) as [4_MT_C],	sum(cst.[ 2-2.5 MT_Conn]) as [5_MT_C],	sum(cst.[ 2.5-3 MT_Conn]) as [6_MT_C],
		sum(cst.[ 3-3.5 MT_Conn]) as [7_MT_C],	sum(cst.[ 3.5-4 MT_Conn]) as [8_MT_C],	sum(cst.[ 4-4.5 MT_Conn]) as [9_MT_C],
		sum(cst.[ 4.5-5 MT_Conn]) as [10_MT_C],	sum(cst.[ 5-5.5 MT_Conn]) as [11_MT_C],	sum(cst.[ 5.5-6 MT_Conn]) as [12_MT_C],
		sum(cst.[ 6-6.5 MT_Conn]) as [13_MT_C],	sum(cst.[ 6.5-7 MT_Conn]) as [14_MT_C],	sum(cst.[ 7-7.5 MT_Conn]) as [15_MT_C],
		sum(cst.[ 7.5-8 MT_Conn]) as [16_MT_C],	sum(cst.[ 8-8.5 MT_Conn]) as [17_MT_C],	sum(cst.[ 8.5-9 MT_Conn]) as [18_MT_C],
		sum(cst.[ 9-9.5 MT_Conn]) as [19_MT_C],	sum(cst.[ 9.5-10 MT_Conn]) as [20_MT_C],	sum(cst.[ 10-10.5 MT_Conn]) as [21_MT_C],
		sum(cst.[ 10.5-11 MT_Conn]) as [22_MT_C],	sum(cst.[ 11-11.5 MT_Conn]) as [23_MT_C],	sum(cst.[ 11.5-12 MT_Conn]) as [24_MT_C],
		sum(cst.[ 12-12.5 MT_Conn]) as [25_MT_C],	sum(cst.[ 12.5-13 MT_Conn]) as [26_MT_C],	sum(cst.[ 13-13.5 MT_Conn]) as [27_MT_C],
		sum(cst.[ 13.5-14 MT_Conn]) as [28_MT_C],	sum(cst.[ 14-14.5 MT_Conn]) as [29_MT_C],	sum(cst.[ 14.5-15 MT_Conn]) as [30_MT_C],
		sum(cst.[ 15-15.5 MT_Conn]) as [31_MT_C],	sum(cst.[ 15.5-16 MT_Conn]) as [32_MT_C],	sum(cst.[ 16-16.5 MT_Conn]) as [33_MT_C],
		sum(cst.[ 16.5-17 MT_Conn]) as [34_MT_C],	sum(cst.[ 17-17.5 MT_Conn]) as [35_MT_C],	sum(cst.[ 17.5-18 MT_Conn]) as [36_MT_C],
		sum(cst.[ 18-18.5 MT_Conn]) as [37_MT_C],	sum(cst.[ 18.5-19 MT_Conn]) as [38_MT_C],	sum(cst.[ 19-19.5 MT_Conn]) as [39_MT_C],
		sum(cst.[ 19.5-20 MT_Conn]) as [40_MT_C],	sum(cst.[ >20 MT_Conn]) as [41_MT_C],

		---------------------------------
		-- Rangos MOMT CONNECT:
		sum(cst.[ 0-0.5 MOMT_Conn]) as [1_MOMT_C],	sum(cst.[ 0.5-1 MOMT_Conn]) as [2_MOMT_C],	sum(cst.[ 1-1.5 MOMT_Conn]) as [3_MOMT_C],
		sum(cst.[ 1.5-2 MOMT_Conn]) as [4_MOMT_C],	sum(cst.[ 2-2.5 MOMT_Conn]) as [5_MOMT_C],	sum(cst.[ 2.5-3 MOMT_Conn]) as [6_MOMT_C],
		sum(cst.[ 3-3.5 MOMT_Conn]) as [7_MOMT_C],	sum(cst.[ 3.5-4 MOMT_Conn]) as [8_MOMT_C],	sum(cst.[ 4-4.5 MOMT_Conn]) as [9_MOMT_C],
		sum(cst.[ 4.5-5 MOMT_Conn]) as [10_MOMT_C],	sum(cst.[ 5-5.5 MOMT_Conn]) as [11_MOMT_C],	sum(cst.[ 5.5-6 MOMT_Conn]) as [12_MOMT_C],
		sum(cst.[ 6-6.5 MOMT_Conn]) as [13_MOMT_C],	sum(cst.[ 6.5-7 MOMT_Conn]) as [14_MOMT_C],	sum(cst.[ 7-7.5 MOMT_Conn]) as [15_MOMT_C],
		sum(cst.[ 7.5-8 MOMT_Conn]) as [16_MOMT_C],	sum(cst.[ 8-8.5 MOMT_Conn]) as [17_MOMT_C],	sum(cst.[ 8.5-9 MOMT_Conn]) as [18_MOMT_C],
		sum(cst.[ 9-9.5 MOMT_Conn]) as [19_MOMT_C],	sum(cst.[ 9.5-10 MOMT_Conn]) as [20_MOMT_C],	sum(cst.[ 10-10.5 MOMT_Conn]) as [21_MOMT_C],
		sum(cst.[ 10.5-11 MOMT_Conn]) as [22_MOMT_C],	sum(cst.[ 11-11.5 MOMT_Conn]) as [23_MOMT_C],	sum(cst.[ 11.5-12 MOMT_Conn]) as [24_MOMT_C],
		sum(cst.[ 12-12.5 MOMT_Conn]) as [25_MOMT_C],	sum(cst.[ 12.5-13 MOMT_Conn]) as [26_MOMT_C],	sum(cst.[ 13-13.5 MOMT_Conn]) as [27_MOMT_C],
		sum(cst.[ 13.5-14 MOMT_Conn]) as [28_MOMT_C],	sum(cst.[ 14-14.5 MOMT_Conn]) as [29_MOMT_C],	sum(cst.[ 14.5-15 MOMT_Conn]) as [30_MOMT_C],
		sum(cst.[ 15-15.5 MOMT_Conn]) as [31_MOMT_C],	sum(cst.[ 15.5-16 MOMT_Conn]) as [32_MOMT_C],	sum(cst.[ 16-16.5 MOMT_Conn]) as [33_MOMT_C],
		sum(cst.[ 16.5-17 MOMT_Conn]) as [34_MOMT_C],	sum(cst.[ 17-17.5 MOMT_Conn]) as [35_MOMT_C],	sum(cst.[ 17.5-18 MOMT_Conn]) as [36_MOMT_C],
		sum(cst.[ 18-18.5 MOMT_Conn]) as [37_MOMT_C],	sum(cst.[ 18.5-19 MOMT_Conn]) as [38_MOMT_C],	sum(cst.[ 19-19.5 MOMT_Conn]) as [39_MOMT_C],
		sum(cst.[ 19.5-20 MOMT_Conn]) as [40_MOMT_C],	sum(cst.[ >20 MOMT_Conn]) as [41_MOMT_C],

		---------------------------------
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end as Region_Road_VF,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end as Region_Road_OSP,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]


	from [AGGRVoice4G].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls] cst, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,mnc,meas_round,Date_Reporting,Week_Reporting,entidad, Report_Type, aggr_type
		, cst.calltype, cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]--,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end
   
	---------
	-- Road 4G:
	insert into _RI_Voice_cst
	select 
		cst.calltype as Calltype,
		p.codigo_ine, 'Roads' vf_environment,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week, 
	   'Road 4G' as meas_Tech, 1 as info_available, entidad as vf_entity, Report_Type, aggr_type,
 
		--0.001*(1000.0*SUM(CST.[CST_MOMT_Alerting]*(CST.[MO_CallType]+CST.[MT_CallType]))) as CST_ALERTING_NUM,
		--0.001*(1000.0*SUM(CST.[CST_MOMT_Connect]*(CST.[MO_CallType]+CST.[MT_CallType]))) as CST_CONNECT_NUM,

		--20170710 : @MDM: Cambio en el cálculo del cálculo del CST considerando el mismo campo en el numerador y el denominador para el ponderado
		0.001*(1000.0*SUM(CST.[CST_MOMT_Alerting]*(CST.[Calls_AVG_ALERT_MO]+CST.[Calls_AVG_ALERT_MT]))) as CST_ALERTING_NUM,
		0.001*(1000.0*SUM(CST.[CST_MOMT_Connect]*(CST.[Calls_AVG_CONNECT_MO]+CST.[Calls_AVG_CONNECT_MT]))) as CST_CONNECT_NUM,


		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(cst.[Calls_AVG_ALERT_MO]) as CST_MO_AL_samples,
		sum(cst.[Calls_AVG_ALERT_MT]) as CST_MT_AL_samples,
		sum(cst.[Calls_AVG_CONNECT_MO]) as CST_MO_CO_Samples,
		sum(cst.[Calls_AVG_CONNECT_MT]) as CST_MT_CO_Samples,

		0.001*(1000.0*SUM(CST.[CST_MO_Alerting]*CST.[Calls_AVG_ALERT_MO])) as CST_MO_AL_NUM,
		0.001*(1000.0*SUM(CST.[CST_MT_Alerting]*CST.[Calls_AVG_ALERT_MT])) as CST_MT_AL_NUM,
		0.001*(1000.0*SUM(CST.[CST_MO_Connect]*CST.[Calls_AVG_CONNECT_MO])) as CST_MO_CO_NUM,
		0.001*(1000.0*SUM(CST.[CST_MT_Connect]*CST.[Calls_AVG_CONNECT_MT])) as CST_MT_CO_NUM,

		---------------------------------
		-- Rangos MO ALERTING:
		sum(cst.[ 0-0.5 MO_Alert]) as [1_MO_A],	sum(cst.[ 0.5-1 MO_Alert]) as [2_MO_A],		sum(cst.[ 1-1.5 MO_Alert]) as [3_MO_A],
		sum(cst.[ 1.5-2 MO_Alert]) as [4_MO_A],	sum(cst.[ 2-2.5 MO_Alert]) as [5_MO_A],		sum(cst.[ 2.5-3 MO_Alert]) as [6_MO_A],
		sum(cst.[ 3-3.5 MO_Alert]) as [7_MO_A],	sum(cst.[ 3.5-4 MO_Alert]) as [8_MO_A],		sum(cst.[ 4-4.5 MO_Alert]) as [9_MO_A],
		sum(cst.[ 4.5-5 MO_Alert]) as [10_MO_A],	sum(cst.[ 5-5.5 MO_Alert]) as [11_MO_A],		sum(cst.[ 5.5-6 MO_Alert]) as [12_MO_A],
		sum(cst.[ 6-6.5 MO_Alert]) as [13_MO_A],	sum(cst.[ 6.5-7 MO_Alert]) as [14_MO_A],		sum(cst.[ 7-7.5 MO_Alert]) as [15_MO_A],
		sum(cst.[ 7.5-8 MO_Alert]) as [16_MO_A],	sum(cst.[ 8-8.5 MO_Alert]) as [17_MO_A],		sum(cst.[ 8.5-9 MO_Alert]) as [18_MO_A],
		sum(cst.[ 9-9.5 MO_Alert]) as [19_MO_A],	sum(cst.[ 9.5-10 MO_Alert]) as [20_MO_A],		sum(cst.[ 10-10.5 MO_Alert]) as [21_MO_A],
		sum(cst.[ 10.5-11 MO_Alert]) as [22_MO_A],	sum(cst.[ 11-11.5 MO_Alert]) as [23_MO_A],	sum(cst.[ 11.5-12 MO_Alert]) as [24_MO_A],
		sum(cst.[ 12-12.5 MO_Alert]) as [25_MO_A],	sum(cst.[ 12.5-13 MO_Alert]) as [26_MO_A],	sum(cst.[ 13-13.5 MO_Alert]) as [27_MO_A],
		sum(cst.[ 13.5-14 MO_Alert]) as [28_MO_A],	sum(cst.[ 14-14.5 MO_Alert]) as [29_MO_A],	sum(cst.[ 14.5-15 MO_Alert]) as [30_MO_A],
		sum(cst.[ 15-15.5 MO_Alert]) as [31_MO_A],	sum(cst.[ 15.5-16 MO_Alert]) as [32_MO_A],	sum(cst.[ 16-16.5 MO_Alert]) as [33_MO_A],
		sum(cst.[ 16.5-17 MO_Alert]) as [34_MO_A],	sum(cst.[ 17-17.5 MO_Alert]) as [35_MO_A],	sum(cst.[ 17.5-18 MO_Alert]) as [36_MO_A],
		sum(cst.[ 18-18.5 MO_Alert]) as [37_MO_A],	sum(cst.[ 18.5-19 MO_Alert]) as [38_MO_A],	sum(cst.[ 19-19.5 MO_Alert]) as [39_MO_A],
		sum(cst.[ 19.5-20 MO_Alert]) as [40_MO_A],	sum(cst.[ >20 MO_Alert]) as [41_MO_A],
		
		---------------------------------
		-- Rangos MT ALERTING:
		sum(cst.[ 0-0.5 MT_Alert]) as [1_MT_A],	sum(cst.[ 0.5-1 MT_Alert]) as [2_MT_A],		sum(cst.[ 1-1.5 MT_Alert]) as [3_MT_A],
		sum(cst.[ 1.5-2 MT_Alert]) as [4_MT_A],	sum(cst.[ 2-2.5 MT_Alert]) as [5_MT_A],		sum(cst.[ 2.5-3 MT_Alert]) as [6_MT_A],
		sum(cst.[ 3-3.5 MT_Alert]) as [7_MT_A],	sum(cst.[ 3.5-4 MT_Alert]) as [8_MT_A],		sum(cst.[ 4-4.5 MT_Alert]) as [9_MT_A],
		sum(cst.[ 4.5-5 MT_Alert]) as [10_MT_A],	sum(cst.[ 5-5.5 MT_Alert]) as [11_MT_A],		sum(cst.[ 5.5-6 MT_Alert]) as [12_MT_A],
		sum(cst.[ 6-6.5 MT_Alert]) as [13_MT_A],	sum(cst.[ 6.5-7 MT_Alert]) as [14_MT_A],		sum(cst.[ 7-7.5 MT_Alert]) as [15_MT_A],
		sum(cst.[ 7.5-8 MT_Alert]) as [16_MT_A],	sum(cst.[ 8-8.5 MT_Alert]) as [17_MT_A],		sum(cst.[ 8.5-9 MT_Alert]) as [18_MT_A],
		sum(cst.[ 9-9.5 MT_Alert]) as [19_MT_A],	sum(cst.[ 9.5-10 MT_Alert]) as [20_MT_A],		sum(cst.[ 10-10.5 MT_Alert]) as [21_MT_A],
		sum(cst.[ 10.5-11 MT_Alert]) as [22_MT_A],	sum(cst.[ 11-11.5 MT_Alert]) as [23_MT_A],	sum(cst.[ 11.5-12 MT_Alert]) as [24_MT_A],
		sum(cst.[ 12-12.5 MT_Alert]) as [25_MT_A],	sum(cst.[ 12.5-13 MT_Alert]) as [26_MT_A],	sum(cst.[ 13-13.5 MT_Alert]) as [27_MT_A],
		sum(cst.[ 13.5-14 MT_Alert]) as [28_MT_A],	sum(cst.[ 14-14.5 MT_Alert]) as [29_MT_A],	sum(cst.[ 14.5-15 MT_Alert]) as [30_MT_A],
		sum(cst.[ 15-15.5 MT_Alert]) as [31_MT_A],	sum(cst.[ 15.5-16 MT_Alert]) as [32_MT_A],	sum(cst.[ 16-16.5 MT_Alert]) as [33_MT_A],
		sum(cst.[ 16.5-17 MT_Alert]) as [34_MT_A],	sum(cst.[ 17-17.5 MT_Alert]) as [35_MT_A],	sum(cst.[ 17.5-18 MT_Alert]) as [36_MT_A],
		sum(cst.[ 18-18.5 MT_Alert]) as [37_MT_A],	sum(cst.[ 18.5-19 MT_Alert]) as [38_MT_A],	sum(cst.[ 19-19.5 MT_Alert]) as [39_MT_A],
		sum(cst.[ 19.5-20 MT_Alert]) as [40_MT_A],	sum(cst.[ >20 MT_Alert]) as [41_MT_A],

		---------------------------------
		-- Rangos MOMT ALERTING:
		sum(cst.[ 0-0.5 MOMT_Alert]) as [1_MOMT_A],	sum(cst.[ 0.5-1 MOMT_Alert]) as [2_MOMT_A],	sum(cst.[ 1-1.5 MOMT_Alert]) as [3_MOMT_A],
		sum(cst.[ 1.5-2 MOMT_Alert]) as [4_MOMT_A],	sum(cst.[ 2-2.5 MOMT_Alert]) as [5_MOMT_A],	sum(cst.[ 2.5-3 MOMT_Alert]) as [6_MOMT_A],
		sum(cst.[ 3-3.5 MOMT_Alert]) as [7_MOMT_A],	sum(cst.[ 3.5-4 MOMT_Alert]) as [8_MOMT_A],	sum(cst.[ 4-4.5 MOMT_Alert]) as [9_MOMT_A],
		sum(cst.[ 4.5-5 MOMT_Alert]) as [10_MOMT_A],	sum(cst.[ 5-5.5 MOMT_Alert]) as [11_MOMT_A],	sum(cst.[ 5.5-6 MOMT_Alert]) as [12_MOMT_A],
		sum(cst.[ 6-6.5 MOMT_Alert]) as [13_MOMT_A],	sum(cst.[ 6.5-7 MOMT_Alert]) as [14_MOMT_A],	sum(cst.[ 7-7.5 MOMT_Alert]) as [15_MOMT_A],
		sum(cst.[ 7.5-8 MOMT_Alert]) as [16_MOMT_A],	sum(cst.[ 8-8.5 MOMT_Alert]) as [17_MOMT_A],	sum(cst.[ 8.5-9 MOMT_Alert]) as [18_MOMT_A],
		sum(cst.[ 9-9.5 MOMT_Alert]) as [19_MOMT_A],	sum(cst.[ 9.5-10 MOMT_Alert]) as [20_MOMT_A],	sum(cst.[ 10-10.5 MOMT_Alert]) as [21_MOMT_A],
		sum(cst.[ 10.5-11 MOMT_Alert]) as [22_MOMT_A],	sum(cst.[ 11-11.5 MOMT_Alert]) as [23_MOMT_A],	sum(cst.[ 11.5-12 MOMT_Alert]) as [24_MOMT_A],
		sum(cst.[ 12-12.5 MOMT_Alert]) as [25_MOMT_A],	sum(cst.[ 12.5-13 MOMT_Alert]) as [26_MOMT_A],	sum(cst.[ 13-13.5 MOMT_Alert]) as [27_MOMT_A],
		sum(cst.[ 13.5-14 MOMT_Alert]) as [28_MOMT_A],	sum(cst.[ 14-14.5 MOMT_Alert]) as [29_MOMT_A],	sum(cst.[ 14.5-15 MOMT_Alert]) as [30_MOMT_A],
		sum(cst.[ 15-15.5 MOMT_Alert]) as [31_MOMT_A],	sum(cst.[ 15.5-16 MOMT_Alert]) as [32_MOMT_A],	sum(cst.[ 16-16.5 MOMT_Alert]) as [33_MOMT_A],
		sum(cst.[ 16.5-17 MOMT_Alert]) as [34_MOMT_A],	sum(cst.[ 17-17.5 MOMT_Alert]) as [35_MOMT_A],	sum(cst.[ 17.5-18 MOMT_Alert]) as [36_MOMT_A],
		sum(cst.[ 18-18.5 MOMT_Alert]) as [37_MOMT_A],	sum(cst.[ 18.5-19 MOMT_Alert]) as [38_MOMT_A],	sum(cst.[ 19-19.5 MOMT_Alert]) as [39_MOMT_A],
		sum(cst.[ 19.5-20 MOMT_Alert]) as [40_MOMT_A],	sum(cst.[ >20 MOMT_Alert]) as [41_MOMT_A],

		---------------------------------
		-- Rangos MO CONNECT:
		sum(cst.[ 0-0.5 MO_Conn]) as [1_MO_C],	sum(cst.[ 0.5-1 MO_Conn]) as [2_MO_C],	sum(cst.[ 1-1.5 MO_Conn]) as [3_MO_C],
		sum(cst.[ 1.5-2 MO_Conn]) as [4_MO_C],	sum(cst.[ 2-2.5 MO_Conn]) as [5_MO_C],	sum(cst.[ 2.5-3 MO_Conn]) as [6_MO_C],	
		sum(cst.[ 3-3.5 MO_Conn]) as [7_MO_C],	sum(cst.[ 3.5-4 MO_Conn]) as [8_MO_C],	sum(cst.[ 4-4.5 MO_Conn]) as [9_MO_C],
		sum(cst.[ 4.5-5 MO_Conn]) as [10_MO_C],	sum(cst.[ 5-5.5 MO_Conn]) as [11_MO_C],	sum(cst.[ 5.5-6 MO_Conn]) as [12_MO_C],
		sum(cst.[ 6-6.5 MO_Conn]) as [13_MO_C],	sum(cst.[ 6.5-7 MO_Conn]) as [14_MO_C],	sum(cst.[ 7-7.5 MO_Conn]) as [15_MO_C],
		sum(cst.[ 7.5-8 MO_Conn]) as [16_MO_C],	sum(cst.[ 8-8.5 MO_Conn]) as [17_MO_C],	sum(cst.[ 8.5-9 MO_Conn]) as [18_MO_C],
		sum(cst.[ 9-9.5 MO_Conn]) as [19_MO_C],	sum(cst.[ 9.5-10 MO_Conn]) as [20_MO_C],	sum(cst.[ 10-10.5 MO_Conn]) as [21_MO_C],
		sum(cst.[ 10.5-11 MO_Conn]) as [22_MO_C],	sum(cst.[ 11-11.5 MO_Conn]) as [23_MO_C],	sum(cst.[ 11.5-12 MO_Conn]) as [24_MO_C],
		sum(cst.[ 12-12.5 MO_Conn]) as [25_MO_C],	sum(cst.[ 12.5-13 MO_Conn]) as [26_MO_C],	sum(cst.[ 13-13.5 MO_Conn]) as [27_MO_C],
		sum(cst.[ 13.5-14 MO_Conn]) as [28_MO_C],	sum(cst.[ 14-14.5 MO_Conn]) as [29_MO_C],	sum(cst.[ 14.5-15 MO_Conn]) as [30_MO_C],
		sum(cst.[ 15-15.5 MO_Conn]) as [31_MO_C],	sum(cst.[ 15.5-16 MO_Conn]) as [32_MO_C],	sum(cst.[ 16-16.5 MO_Conn]) as [33_MO_C],
		sum(cst.[ 16.5-17 MO_Conn]) as [34_MO_C],	sum(cst.[ 17-17.5 MO_Conn]) as [35_MO_C],	sum(cst.[ 17.5-18 MO_Conn]) as [36_MO_C],
		sum(cst.[ 18-18.5 MO_Conn]) as [37_MO_C],	sum(cst.[ 18.5-19 MO_Conn]) as [38_MO_C],	sum(cst.[ 19-19.5 MO_Conn]) as [39_MO_C],
		sum(cst.[ 19.5-20 MO_Conn]) as [40_MO_C],	sum(cst.[ >20 MO_Conn]) as [41_MO_C],

		---------------------------------
		-- Rangos MT CONNECT:
		sum(cst.[ 0-0.5 MT_Conn]) as [1_MT_C],	sum(cst.[ 0.5-1 MT_Conn]) as [2_MT_C],	sum(cst.[ 1-1.5 MT_Conn]) as [3_MT_C],
		sum(cst.[ 1.5-2 MT_Conn]) as [4_MT_C],	sum(cst.[ 2-2.5 MT_Conn]) as [5_MT_C],	sum(cst.[ 2.5-3 MT_Conn]) as [6_MT_C],
		sum(cst.[ 3-3.5 MT_Conn]) as [7_MT_C],	sum(cst.[ 3.5-4 MT_Conn]) as [8_MT_C],	sum(cst.[ 4-4.5 MT_Conn]) as [9_MT_C],
		sum(cst.[ 4.5-5 MT_Conn]) as [10_MT_C],	sum(cst.[ 5-5.5 MT_Conn]) as [11_MT_C],	sum(cst.[ 5.5-6 MT_Conn]) as [12_MT_C],
		sum(cst.[ 6-6.5 MT_Conn]) as [13_MT_C],	sum(cst.[ 6.5-7 MT_Conn]) as [14_MT_C],	sum(cst.[ 7-7.5 MT_Conn]) as [15_MT_C],
		sum(cst.[ 7.5-8 MT_Conn]) as [16_MT_C],	sum(cst.[ 8-8.5 MT_Conn]) as [17_MT_C],	sum(cst.[ 8.5-9 MT_Conn]) as [18_MT_C],
		sum(cst.[ 9-9.5 MT_Conn]) as [19_MT_C],	sum(cst.[ 9.5-10 MT_Conn]) as [20_MT_C],	sum(cst.[ 10-10.5 MT_Conn]) as [21_MT_C],
		sum(cst.[ 10.5-11 MT_Conn]) as [22_MT_C],	sum(cst.[ 11-11.5 MT_Conn]) as [23_MT_C],	sum(cst.[ 11.5-12 MT_Conn]) as [24_MT_C],
		sum(cst.[ 12-12.5 MT_Conn]) as [25_MT_C],	sum(cst.[ 12.5-13 MT_Conn]) as [26_MT_C],	sum(cst.[ 13-13.5 MT_Conn]) as [27_MT_C],
		sum(cst.[ 13.5-14 MT_Conn]) as [28_MT_C],	sum(cst.[ 14-14.5 MT_Conn]) as [29_MT_C],	sum(cst.[ 14.5-15 MT_Conn]) as [30_MT_C],
		sum(cst.[ 15-15.5 MT_Conn]) as [31_MT_C],	sum(cst.[ 15.5-16 MT_Conn]) as [32_MT_C],	sum(cst.[ 16-16.5 MT_Conn]) as [33_MT_C],
		sum(cst.[ 16.5-17 MT_Conn]) as [34_MT_C],	sum(cst.[ 17-17.5 MT_Conn]) as [35_MT_C],	sum(cst.[ 17.5-18 MT_Conn]) as [36_MT_C],
		sum(cst.[ 18-18.5 MT_Conn]) as [37_MT_C],	sum(cst.[ 18.5-19 MT_Conn]) as [38_MT_C],	sum(cst.[ 19-19.5 MT_Conn]) as [39_MT_C],
		sum(cst.[ 19.5-20 MT_Conn]) as [40_MT_C],	sum(cst.[ >20 MT_Conn]) as [41_MT_C],

		---------------------------------
		-- Rangos MOMT CONNECT:
		sum(cst.[ 0-0.5 MOMT_Conn]) as [1_MOMT_C],	sum(cst.[ 0.5-1 MOMT_Conn]) as [2_MOMT_C],	sum(cst.[ 1-1.5 MOMT_Conn]) as [3_MOMT_C],
		sum(cst.[ 1.5-2 MOMT_Conn]) as [4_MOMT_C],	sum(cst.[ 2-2.5 MOMT_Conn]) as [5_MOMT_C],	sum(cst.[ 2.5-3 MOMT_Conn]) as [6_MOMT_C],
		sum(cst.[ 3-3.5 MOMT_Conn]) as [7_MOMT_C],	sum(cst.[ 3.5-4 MOMT_Conn]) as [8_MOMT_C],	sum(cst.[ 4-4.5 MOMT_Conn]) as [9_MOMT_C],
		sum(cst.[ 4.5-5 MOMT_Conn]) as [10_MOMT_C],	sum(cst.[ 5-5.5 MOMT_Conn]) as [11_MOMT_C],	sum(cst.[ 5.5-6 MOMT_Conn]) as [12_MOMT_C],
		sum(cst.[ 6-6.5 MOMT_Conn]) as [13_MOMT_C],	sum(cst.[ 6.5-7 MOMT_Conn]) as [14_MOMT_C],	sum(cst.[ 7-7.5 MOMT_Conn]) as [15_MOMT_C],
		sum(cst.[ 7.5-8 MOMT_Conn]) as [16_MOMT_C],	sum(cst.[ 8-8.5 MOMT_Conn]) as [17_MOMT_C],	sum(cst.[ 8.5-9 MOMT_Conn]) as [18_MOMT_C],
		sum(cst.[ 9-9.5 MOMT_Conn]) as [19_MOMT_C],	sum(cst.[ 9.5-10 MOMT_Conn]) as [20_MOMT_C],	sum(cst.[ 10-10.5 MOMT_Conn]) as [21_MOMT_C],
		sum(cst.[ 10.5-11 MOMT_Conn]) as [22_MOMT_C],	sum(cst.[ 11-11.5 MOMT_Conn]) as [23_MOMT_C],	sum(cst.[ 11.5-12 MOMT_Conn]) as [24_MOMT_C],
		sum(cst.[ 12-12.5 MOMT_Conn]) as [25_MOMT_C],	sum(cst.[ 12.5-13 MOMT_Conn]) as [26_MOMT_C],	sum(cst.[ 13-13.5 MOMT_Conn]) as [27_MOMT_C],
		sum(cst.[ 13.5-14 MOMT_Conn]) as [28_MOMT_C],	sum(cst.[ 14-14.5 MOMT_Conn]) as [29_MOMT_C],	sum(cst.[ 14.5-15 MOMT_Conn]) as [30_MOMT_C],
		sum(cst.[ 15-15.5 MOMT_Conn]) as [31_MOMT_C],	sum(cst.[ 15.5-16 MOMT_Conn]) as [32_MOMT_C],	sum(cst.[ 16-16.5 MOMT_Conn]) as [33_MOMT_C],
		sum(cst.[ 16.5-17 MOMT_Conn]) as [34_MOMT_C],	sum(cst.[ 17-17.5 MOMT_Conn]) as [35_MOMT_C],	sum(cst.[ 17.5-18 MOMT_Conn]) as [36_MOMT_C],
		sum(cst.[ 18-18.5 MOMT_Conn]) as [37_MOMT_C],	sum(cst.[ 18.5-19 MOMT_Conn]) as [38_MOMT_C],	sum(cst.[ 19-19.5 MOMT_Conn]) as [39_MOMT_C],
		sum(cst.[ 19.5-20 MOMT_Conn]) as [40_MOMT_C],	sum(cst.[ >20 MOMT_Conn]) as [41_MOMT_C],

		---------------------------------
		--cst.Region_VF as Region_Road_VF, cst.Region_OSP as Region_Road_OSP,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]

	from	[AGGRVoice4G_Road].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls] cst, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,mnc,meas_round,Date_Reporting,Week_Reporting,entidad, Report_Type, aggr_type, cst.calltype,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]--, cst.Region_VF, cst.Region_OSP

	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 3.1 CST 3G, 4G y Road', getdate()

	----------------------------------------------------------------------------------------------------------
	/*		3.2	Cruzamos con la tabla de 4G para saber qué entidades tenemos que reportar para 4GOnly. 
				Si una medida no ha cursado nada en esta tecnología saldría vacía.							*/
	---------------------------------------------------------------------------------------------------------- 
	print '3.2 CST 4GOnly y 4GOnly_Road'
	-----------	
	-- 4GOnly:
	insert into _RI_Voice_cst
	select 
		cst.calltype as Calltype,
		p.codigo_ine, case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,cst.mnc,cst.meas_round,cst.Date_Reporting as meas_date,cst.Week_Reporting as meas_week, 
	   '4GOnly' as meas_Tech, 1 as info_available,cst.entidad as vf_entity,cst.Report_Type,cst.aggr_type,
    
		0.001*(1000.0*SUM(C4G.[CST_MOMT_Alerting]*(C4G.[Calls_AVG_ALERT_MO]+C4G.[Calls_AVG_ALERT_MT]))) as CST_ALERTING_NUM,
		0.001*(1000.0*SUM(C4G.[CST_MOMT_Connect]*(C4G.[Calls_AVG_CONNECT_MO]+C4G.[Calls_AVG_CONNECT_MT]))) as CST_CONNECT_NUM,

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(C4G.[Calls_AVG_ALERT_MO]) as CST_MO_AL_samples,
		sum(C4G.[Calls_AVG_ALERT_MT]) as CST_MT_AL_samples,
		sum(C4G.[Calls_AVG_CONNECT_MO]) as CST_MO_CO_Samples,
		sum(C4G.[Calls_AVG_CONNECT_MT]) as CST_MT_CO_Samples,

		0.001*(1000.0*SUM(C4G.[CST_MO_Alerting]*C4G.[Calls_AVG_ALERT_MO])) as CST_MO_AL_NUM,
		0.001*(1000.0*SUM(C4G.[CST_MT_Alerting]*C4G.[Calls_AVG_ALERT_MT])) as CST_MT_AL_NUM,
		0.001*(1000.0*SUM(C4G.[CST_MO_Connect]*C4G.[Calls_AVG_CONNECT_MO])) as CST_MO_CO_NUM,
		0.001*(1000.0*SUM(C4G.[CST_MT_Connect]*C4G.[Calls_AVG_CONNECT_MT])) as CST_MT_CO_NUM,

		---------------------------------
		-- Rangos MO ALERTING:
		sum(C4G.[ 0-0.5 MO_Alert]) as [1_MO_A],	sum(C4G.[ 0.5-1 MO_Alert]) as [2_MO_A],		sum(C4G.[ 1-1.5 MO_Alert]) as [3_MO_A],
		sum(C4G.[ 1.5-2 MO_Alert]) as [4_MO_A],	sum(C4G.[ 2-2.5 MO_Alert]) as [5_MO_A],		sum(C4G.[ 2.5-3 MO_Alert]) as [6_MO_A],
		sum(C4G.[ 3-3.5 MO_Alert]) as [7_MO_A],	sum(C4G.[ 3.5-4 MO_Alert]) as [8_MO_A],		sum(C4G.[ 4-4.5 MO_Alert]) as [9_MO_A],
		sum(C4G.[ 4.5-5 MO_Alert]) as [10_MO_A],	sum(C4G.[ 5-5.5 MO_Alert]) as [11_MO_A],		sum(C4G.[ 5.5-6 MO_Alert]) as [12_MO_A],
		sum(C4G.[ 6-6.5 MO_Alert]) as [13_MO_A],	sum(C4G.[ 6.5-7 MO_Alert]) as [14_MO_A],		sum(C4G.[ 7-7.5 MO_Alert]) as [15_MO_A],
		sum(C4G.[ 7.5-8 MO_Alert]) as [16_MO_A],	sum(C4G.[ 8-8.5 MO_Alert]) as [17_MO_A],		sum(C4G.[ 8.5-9 MO_Alert]) as [18_MO_A],
		sum(C4G.[ 9-9.5 MO_Alert]) as [19_MO_A],	sum(C4G.[ 9.5-10 MO_Alert]) as [20_MO_A],		sum(C4G.[ 10-10.5 MO_Alert]) as [21_MO_A],
		sum(C4G.[ 10.5-11 MO_Alert]) as [22_MO_A],	sum(C4G.[ 11-11.5 MO_Alert]) as [23_MO_A],	sum(C4G.[ 11.5-12 MO_Alert]) as [24_MO_A],
		sum(C4G.[ 12-12.5 MO_Alert]) as [25_MO_A],	sum(C4G.[ 12.5-13 MO_Alert]) as [26_MO_A],	sum(C4G.[ 13-13.5 MO_Alert]) as [27_MO_A],
		sum(C4G.[ 13.5-14 MO_Alert]) as [28_MO_A],	sum(C4G.[ 14-14.5 MO_Alert]) as [29_MO_A],	sum(C4G.[ 14.5-15 MO_Alert]) as [30_MO_A],
		sum(C4G.[ 15-15.5 MO_Alert]) as [31_MO_A],	sum(C4G.[ 15.5-16 MO_Alert]) as [32_MO_A],	sum(C4G.[ 16-16.5 MO_Alert]) as [33_MO_A],
		sum(C4G.[ 16.5-17 MO_Alert]) as [34_MO_A],	sum(C4G.[ 17-17.5 MO_Alert]) as [35_MO_A],	sum(C4G.[ 17.5-18 MO_Alert]) as [36_MO_A],
		sum(C4G.[ 18-18.5 MO_Alert]) as [37_MO_A],	sum(C4G.[ 18.5-19 MO_Alert]) as [38_MO_A],	sum(C4G.[ 19-19.5 MO_Alert]) as [39_MO_A],
		sum(C4G.[ 19.5-20 MO_Alert]) as [40_MO_A],	sum(C4G.[ >20 MO_Alert]) as [41_MO_A],
		
		---------------------------------
		-- Rangos MT ALERTING:
		sum(C4G.[ 0-0.5 MT_Alert]) as [1_MT_A],	sum(C4G.[ 0.5-1 MT_Alert]) as [2_MT_A],		sum(C4G.[ 1-1.5 MT_Alert]) as [3_MT_A],
		sum(C4G.[ 1.5-2 MT_Alert]) as [4_MT_A],	sum(C4G.[ 2-2.5 MT_Alert]) as [5_MT_A],		sum(C4G.[ 2.5-3 MT_Alert]) as [6_MT_A],
		sum(C4G.[ 3-3.5 MT_Alert]) as [7_MT_A],	sum(C4G.[ 3.5-4 MT_Alert]) as [8_MT_A],		sum(C4G.[ 4-4.5 MT_Alert]) as [9_MT_A],
		sum(C4G.[ 4.5-5 MT_Alert]) as [10_MT_A],	sum(C4G.[ 5-5.5 MT_Alert]) as [11_MT_A],		sum(C4G.[ 5.5-6 MT_Alert]) as [12_MT_A],
		sum(C4G.[ 6-6.5 MT_Alert]) as [13_MT_A],	sum(C4G.[ 6.5-7 MT_Alert]) as [14_MT_A],		sum(C4G.[ 7-7.5 MT_Alert]) as [15_MT_A],
		sum(C4G.[ 7.5-8 MT_Alert]) as [16_MT_A],	sum(C4G.[ 8-8.5 MT_Alert]) as [17_MT_A],		sum(C4G.[ 8.5-9 MT_Alert]) as [18_MT_A],
		sum(C4G.[ 9-9.5 MT_Alert]) as [19_MT_A],	sum(C4G.[ 9.5-10 MT_Alert]) as [20_MT_A],		sum(C4G.[ 10-10.5 MT_Alert]) as [21_MT_A],
		sum(C4G.[ 10.5-11 MT_Alert]) as [22_MT_A],	sum(C4G.[ 11-11.5 MT_Alert]) as [23_MT_A],	sum(C4G.[ 11.5-12 MT_Alert]) as [24_MT_A],
		sum(C4G.[ 12-12.5 MT_Alert]) as [25_MT_A],	sum(C4G.[ 12.5-13 MT_Alert]) as [26_MT_A],	sum(C4G.[ 13-13.5 MT_Alert]) as [27_MT_A],
		sum(C4G.[ 13.5-14 MT_Alert]) as [28_MT_A],	sum(C4G.[ 14-14.5 MT_Alert]) as [29_MT_A],	sum(C4G.[ 14.5-15 MT_Alert]) as [30_MT_A],
		sum(C4G.[ 15-15.5 MT_Alert]) as [31_MT_A],	sum(C4G.[ 15.5-16 MT_Alert]) as [32_MT_A],	sum(C4G.[ 16-16.5 MT_Alert]) as [33_MT_A],
		sum(C4G.[ 16.5-17 MT_Alert]) as [34_MT_A],	sum(C4G.[ 17-17.5 MT_Alert]) as [35_MT_A],	sum(C4G.[ 17.5-18 MT_Alert]) as [36_MT_A],
		sum(C4G.[ 18-18.5 MT_Alert]) as [37_MT_A],	sum(C4G.[ 18.5-19 MT_Alert]) as [38_MT_A],	sum(C4G.[ 19-19.5 MT_Alert]) as [39_MT_A],
		sum(C4G.[ 19.5-20 MT_Alert]) as [40_MT_A],	sum(C4G.[ >20 MT_Alert]) as [41_MT_A],

		---------------------------------
		-- Rangos MOMT ALERTING:
		sum(C4G.[ 0-0.5 MOMT_Alert]) as [1_MOMT_A],	sum(C4G.[ 0.5-1 MOMT_Alert]) as [2_MOMT_A],	sum(C4G.[ 1-1.5 MOMT_Alert]) as [3_MOMT_A],
		sum(C4G.[ 1.5-2 MOMT_Alert]) as [4_MOMT_A],	sum(C4G.[ 2-2.5 MOMT_Alert]) as [5_MOMT_A],	sum(C4G.[ 2.5-3 MOMT_Alert]) as [6_MOMT_A],
		sum(C4G.[ 3-3.5 MOMT_Alert]) as [7_MOMT_A],	sum(C4G.[ 3.5-4 MOMT_Alert]) as [8_MOMT_A],	sum(C4G.[ 4-4.5 MOMT_Alert]) as [9_MOMT_A],
		sum(C4G.[ 4.5-5 MOMT_Alert]) as [10_MOMT_A],	sum(C4G.[ 5-5.5 MOMT_Alert]) as [11_MOMT_A],	sum(C4G.[ 5.5-6 MOMT_Alert]) as [12_MOMT_A],
		sum(C4G.[ 6-6.5 MOMT_Alert]) as [13_MOMT_A],	sum(C4G.[ 6.5-7 MOMT_Alert]) as [14_MOMT_A],	sum(C4G.[ 7-7.5 MOMT_Alert]) as [15_MOMT_A],
		sum(C4G.[ 7.5-8 MOMT_Alert]) as [16_MOMT_A],	sum(C4G.[ 8-8.5 MOMT_Alert]) as [17_MOMT_A],	sum(C4G.[ 8.5-9 MOMT_Alert]) as [18_MOMT_A],
		sum(C4G.[ 9-9.5 MOMT_Alert]) as [19_MOMT_A],	sum(C4G.[ 9.5-10 MOMT_Alert]) as [20_MOMT_A],	sum(C4G.[ 10-10.5 MOMT_Alert]) as [21_MOMT_A],
		sum(C4G.[ 10.5-11 MOMT_Alert]) as [22_MOMT_A],	sum(C4G.[ 11-11.5 MOMT_Alert]) as [23_MOMT_A],	sum(C4G.[ 11.5-12 MOMT_Alert]) as [24_MOMT_A],
		sum(C4G.[ 12-12.5 MOMT_Alert]) as [25_MOMT_A],	sum(C4G.[ 12.5-13 MOMT_Alert]) as [26_MOMT_A],	sum(C4G.[ 13-13.5 MOMT_Alert]) as [27_MOMT_A],
		sum(C4G.[ 13.5-14 MOMT_Alert]) as [28_MOMT_A],	sum(C4G.[ 14-14.5 MOMT_Alert]) as [29_MOMT_A],	sum(C4G.[ 14.5-15 MOMT_Alert]) as [30_MOMT_A],
		sum(C4G.[ 15-15.5 MOMT_Alert]) as [31_MOMT_A],	sum(C4G.[ 15.5-16 MOMT_Alert]) as [32_MOMT_A],	sum(C4G.[ 16-16.5 MOMT_Alert]) as [33_MOMT_A],
		sum(C4G.[ 16.5-17 MOMT_Alert]) as [34_MOMT_A],	sum(C4G.[ 17-17.5 MOMT_Alert]) as [35_MOMT_A],	sum(C4G.[ 17.5-18 MOMT_Alert]) as [36_MOMT_A],
		sum(C4G.[ 18-18.5 MOMT_Alert]) as [37_MOMT_A],	sum(C4G.[ 18.5-19 MOMT_Alert]) as [38_MOMT_A],	sum(C4G.[ 19-19.5 MOMT_Alert]) as [39_MOMT_A],
		sum(C4G.[ 19.5-20 MOMT_Alert]) as [40_MOMT_A],	sum(C4G.[ >20 MOMT_Alert]) as [41_MOMT_A],

		---------------------------------
		-- Rangos MO CONNECT:
		sum(C4G.[ 0-0.5 MO_Conn]) as [1_MO_C],	sum(C4G.[ 0.5-1 MO_Conn]) as [2_MO_C],	sum(C4G.[ 1-1.5 MO_Conn]) as [3_MO_C],
		sum(C4G.[ 1.5-2 MO_Conn]) as [4_MO_C],	sum(C4G.[ 2-2.5 MO_Conn]) as [5_MO_C],	sum(C4G.[ 2.5-3 MO_Conn]) as [6_MO_C],	
		sum(C4G.[ 3-3.5 MO_Conn]) as [7_MO_C],	sum(C4G.[ 3.5-4 MO_Conn]) as [8_MO_C],	sum(C4G.[ 4-4.5 MO_Conn]) as [9_MO_C],
		sum(C4G.[ 4.5-5 MO_Conn]) as [10_MO_C],	sum(C4G.[ 5-5.5 MO_Conn]) as [11_MO_C],	sum(C4G.[ 5.5-6 MO_Conn]) as [12_MO_C],
		sum(C4G.[ 6-6.5 MO_Conn]) as [13_MO_C],	sum(C4G.[ 6.5-7 MO_Conn]) as [14_MO_C],	sum(C4G.[ 7-7.5 MO_Conn]) as [15_MO_C],
		sum(C4G.[ 7.5-8 MO_Conn]) as [16_MO_C],	sum(C4G.[ 8-8.5 MO_Conn]) as [17_MO_C],	sum(C4G.[ 8.5-9 MO_Conn]) as [18_MO_C],
		sum(C4G.[ 9-9.5 MO_Conn]) as [19_MO_C],	sum(C4G.[ 9.5-10 MO_Conn]) as [20_MO_C],	sum(C4G.[ 10-10.5 MO_Conn]) as [21_MO_C],
		sum(C4G.[ 10.5-11 MO_Conn]) as [22_MO_C],	sum(C4G.[ 11-11.5 MO_Conn]) as [23_MO_C],	sum(C4G.[ 11.5-12 MO_Conn]) as [24_MO_C],
		sum(C4G.[ 12-12.5 MO_Conn]) as [25_MO_C],	sum(C4G.[ 12.5-13 MO_Conn]) as [26_MO_C],	sum(C4G.[ 13-13.5 MO_Conn]) as [27_MO_C],
		sum(C4G.[ 13.5-14 MO_Conn]) as [28_MO_C],	sum(C4G.[ 14-14.5 MO_Conn]) as [29_MO_C],	sum(C4G.[ 14.5-15 MO_Conn]) as [30_MO_C],
		sum(C4G.[ 15-15.5 MO_Conn]) as [31_MO_C],	sum(C4G.[ 15.5-16 MO_Conn]) as [32_MO_C],	sum(C4G.[ 16-16.5 MO_Conn]) as [33_MO_C],
		sum(C4G.[ 16.5-17 MO_Conn]) as [34_MO_C],	sum(C4G.[ 17-17.5 MO_Conn]) as [35_MO_C],	sum(C4G.[ 17.5-18 MO_Conn]) as [36_MO_C],
		sum(C4G.[ 18-18.5 MO_Conn]) as [37_MO_C],	sum(C4G.[ 18.5-19 MO_Conn]) as [38_MO_C],	sum(C4G.[ 19-19.5 MO_Conn]) as [39_MO_C],
		sum(C4G.[ 19.5-20 MO_Conn]) as [40_MO_C],	sum(C4G.[ >20 MO_Conn]) as [41_MO_C],

		---------------------------------
		-- Rangos MT CONNECT:
		sum(C4G.[ 0-0.5 MT_Conn]) as [1_MT_C],	sum(C4G.[ 0.5-1 MT_Conn]) as [2_MT_C],	sum(C4G.[ 1-1.5 MT_Conn]) as [3_MT_C],
		sum(C4G.[ 1.5-2 MT_Conn]) as [4_MT_C],	sum(C4G.[ 2-2.5 MT_Conn]) as [5_MT_C],	sum(C4G.[ 2.5-3 MT_Conn]) as [6_MT_C],
		sum(C4G.[ 3-3.5 MT_Conn]) as [7_MT_C],	sum(C4G.[ 3.5-4 MT_Conn]) as [8_MT_C],	sum(C4G.[ 4-4.5 MT_Conn]) as [9_MT_C],
		sum(C4G.[ 4.5-5 MT_Conn]) as [10_MT_C],	sum(C4G.[ 5-5.5 MT_Conn]) as [11_MT_C],	sum(C4G.[ 5.5-6 MT_Conn]) as [12_MT_C],
		sum(C4G.[ 6-6.5 MT_Conn]) as [13_MT_C],	sum(C4G.[ 6.5-7 MT_Conn]) as [14_MT_C],	sum(C4G.[ 7-7.5 MT_Conn]) as [15_MT_C],
		sum(C4G.[ 7.5-8 MT_Conn]) as [16_MT_C],	sum(C4G.[ 8-8.5 MT_Conn]) as [17_MT_C],	sum(C4G.[ 8.5-9 MT_Conn]) as [18_MT_C],
		sum(C4G.[ 9-9.5 MT_Conn]) as [19_MT_C],	sum(C4G.[ 9.5-10 MT_Conn]) as [20_MT_C],	sum(C4G.[ 10-10.5 MT_Conn]) as [21_MT_C],
		sum(C4G.[ 10.5-11 MT_Conn]) as [22_MT_C],	sum(C4G.[ 11-11.5 MT_Conn]) as [23_MT_C],	sum(C4G.[ 11.5-12 MT_Conn]) as [24_MT_C],
		sum(C4G.[ 12-12.5 MT_Conn]) as [25_MT_C],	sum(C4G.[ 12.5-13 MT_Conn]) as [26_MT_C],	sum(C4G.[ 13-13.5 MT_Conn]) as [27_MT_C],
		sum(C4G.[ 13.5-14 MT_Conn]) as [28_MT_C],	sum(C4G.[ 14-14.5 MT_Conn]) as [29_MT_C],	sum(C4G.[ 14.5-15 MT_Conn]) as [30_MT_C],
		sum(C4G.[ 15-15.5 MT_Conn]) as [31_MT_C],	sum(C4G.[ 15.5-16 MT_Conn]) as [32_MT_C],	sum(C4G.[ 16-16.5 MT_Conn]) as [33_MT_C],
		sum(C4G.[ 16.5-17 MT_Conn]) as [34_MT_C],	sum(C4G.[ 17-17.5 MT_Conn]) as [35_MT_C],	sum(C4G.[ 17.5-18 MT_Conn]) as [36_MT_C],
		sum(C4G.[ 18-18.5 MT_Conn]) as [37_MT_C],	sum(C4G.[ 18.5-19 MT_Conn]) as [38_MT_C],	sum(C4G.[ 19-19.5 MT_Conn]) as [39_MT_C],
		sum(C4G.[ 19.5-20 MT_Conn]) as [40_MT_C],	sum(C4G.[ >20 MT_Conn]) as [41_MT_C],

		---------------------------------
		-- Rangos MOMT CONNECT:
		sum(C4G.[ 0-0.5 MOMT_Conn]) as [1_MOMT_C],	sum(C4G.[ 0.5-1 MOMT_Conn]) as [2_MOMT_C],	sum(C4G.[ 1-1.5 MOMT_Conn]) as [3_MOMT_C],
		sum(C4G.[ 1.5-2 MOMT_Conn]) as [4_MOMT_C],	sum(C4G.[ 2-2.5 MOMT_Conn]) as [5_MOMT_C],	sum(C4G.[ 2.5-3 MOMT_Conn]) as [6_MOMT_C],
		sum(C4G.[ 3-3.5 MOMT_Conn]) as [7_MOMT_C],	sum(C4G.[ 3.5-4 MOMT_Conn]) as [8_MOMT_C],	sum(C4G.[ 4-4.5 MOMT_Conn]) as [9_MOMT_C],
		sum(C4G.[ 4.5-5 MOMT_Conn]) as [10_MOMT_C],	sum(C4G.[ 5-5.5 MOMT_Conn]) as [11_MOMT_C],	sum(C4G.[ 5.5-6 MOMT_Conn]) as [12_MOMT_C],
		sum(C4G.[ 6-6.5 MOMT_Conn]) as [13_MOMT_C],	sum(C4G.[ 6.5-7 MOMT_Conn]) as [14_MOMT_C],	sum(C4G.[ 7-7.5 MOMT_Conn]) as [15_MOMT_C],
		sum(C4G.[ 7.5-8 MOMT_Conn]) as [16_MOMT_C],	sum(C4G.[ 8-8.5 MOMT_Conn]) as [17_MOMT_C],	sum(C4G.[ 8.5-9 MOMT_Conn]) as [18_MOMT_C],
		sum(C4G.[ 9-9.5 MOMT_Conn]) as [19_MOMT_C],	sum(C4G.[ 9.5-10 MOMT_Conn]) as [20_MOMT_C],	sum(C4G.[ 10-10.5 MOMT_Conn]) as [21_MOMT_C],
		sum(C4G.[ 10.5-11 MOMT_Conn]) as [22_MOMT_C],	sum(C4G.[ 11-11.5 MOMT_Conn]) as [23_MOMT_C],	sum(C4G.[ 11.5-12 MOMT_Conn]) as [24_MOMT_C],
		sum(C4G.[ 12-12.5 MOMT_Conn]) as [25_MOMT_C],	sum(C4G.[ 12.5-13 MOMT_Conn]) as [26_MOMT_C],	sum(C4G.[ 13-13.5 MOMT_Conn]) as [27_MOMT_C],
		sum(C4G.[ 13.5-14 MOMT_Conn]) as [28_MOMT_C],	sum(C4G.[ 14-14.5 MOMT_Conn]) as [29_MOMT_C],	sum(C4G.[ 14.5-15 MOMT_Conn]) as [30_MOMT_C],
		sum(C4G.[ 15-15.5 MOMT_Conn]) as [31_MOMT_C],	sum(C4G.[ 15.5-16 MOMT_Conn]) as [32_MOMT_C],	sum(C4G.[ 16-16.5 MOMT_Conn]) as [33_MOMT_C],
		sum(C4G.[ 16.5-17 MOMT_Conn]) as [34_MOMT_C],	sum(C4G.[ 17-17.5 MOMT_Conn]) as [35_MOMT_C],	sum(C4G.[ 17.5-18 MOMT_Conn]) as [36_MOMT_C],
		sum(C4G.[ 18-18.5 MOMT_Conn]) as [37_MOMT_C],	sum(C4G.[ 18.5-19 MOMT_Conn]) as [38_MOMT_C],	sum(C4G.[ 19-19.5 MOMT_Conn]) as [39_MOMT_C],
		sum(C4G.[ 19.5-20 MOMT_Conn]) as [40_MOMT_C],	sum(C4G.[ >20 MOMT_Conn]) as [41_MOMT_C],

		---------------------------------
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end as Region_Road_VF,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end as Region_Road_OSP,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]
	
	from [AGGRVoice4G].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls] cst
			left outer join [AGGRVoice4G].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls_4G] C4G on (isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')=isnull(C4G.parcel,'0.00000 Long, 0.00000 Lat') and cst.mnc=C4G.mnc and cst.Date_Reporting=C4G.Date_Reporting and cst.entidad=C4G.entidad and cst.Aggr_Type=C4G.Aggr_Type and cst.Report_Type=C4G.Report_Type and cst.meas_round=C4G.meas_round) 
		 ,[AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,cst.mnc,cst.meas_round,cst.Date_Reporting,
		cst.Week_Reporting,cst.entidad,cst.Report_Type,cst.aggr_type, cst.calltype, cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]--,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end

	---------
	-- ROAD 4GOnly:
	insert into _RI_Voice_cst
	select 
		cst.calltype as Calltype,
		p.codigo_ine, 'Roads' vf_environment,cst.mnc,cst.meas_round,cst.Date_Reporting as meas_date,cst.Week_Reporting as meas_week, 
	   'Road 4GOnly' as meas_Tech, 1 as info_available,cst.entidad as vf_entity,cst.Report_Type,cst.aggr_type,
    
		0.001*(1000.0*SUM(C4G.[CST_MOMT_Alerting]*(C4G.[Calls_AVG_ALERT_MO]+C4G.[Calls_AVG_ALERT_MT]))) as CST_ALERTING_NUM,
		0.001*(1000.0*SUM(C4G.[CST_MOMT_Connect]*(C4G.[Calls_AVG_CONNECT_MO]+C4G.[Calls_AVG_CONNECT_MT]))) as CST_CONNECT_NUM,

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(C4G.[Calls_AVG_ALERT_MO]) as CST_MO_AL_samples,
		sum(C4G.[Calls_AVG_ALERT_MT]) as CST_MT_AL_samples,
		sum(C4G.[Calls_AVG_CONNECT_MO]) as CST_MO_CO_Samples,
		sum(C4G.[Calls_AVG_CONNECT_MT]) as CST_MT_CO_Samples,

		0.001*(1000.0*SUM(C4G.[CST_MO_Alerting]*C4G.[Calls_AVG_ALERT_MO])) as CST_MO_AL_NUM,
		0.001*(1000.0*SUM(C4G.[CST_MT_Alerting]*C4G.[Calls_AVG_ALERT_MT])) as CST_MT_AL_NUM,
		0.001*(1000.0*SUM(C4G.[CST_MO_Connect]*C4G.[Calls_AVG_CONNECT_MO])) as CST_MO_CO_NUM,
		0.001*(1000.0*SUM(C4G.[CST_MT_Connect]*C4G.[Calls_AVG_CONNECT_MT])) as CST_MT_CO_NUM,

	---------------------------------
		-- Rangos MO ALERTING:
		sum(C4G.[ 0-0.5 MO_Alert]) as [1_MO_A],	sum(C4G.[ 0.5-1 MO_Alert]) as [2_MO_A],		sum(C4G.[ 1-1.5 MO_Alert]) as [3_MO_A],
		sum(C4G.[ 1.5-2 MO_Alert]) as [4_MO_A],	sum(C4G.[ 2-2.5 MO_Alert]) as [5_MO_A],		sum(C4G.[ 2.5-3 MO_Alert]) as [6_MO_A],
		sum(C4G.[ 3-3.5 MO_Alert]) as [7_MO_A],	sum(C4G.[ 3.5-4 MO_Alert]) as [8_MO_A],		sum(C4G.[ 4-4.5 MO_Alert]) as [9_MO_A],
		sum(C4G.[ 4.5-5 MO_Alert]) as [10_MO_A],	sum(C4G.[ 5-5.5 MO_Alert]) as [11_MO_A],		sum(C4G.[ 5.5-6 MO_Alert]) as [12_MO_A],
		sum(C4G.[ 6-6.5 MO_Alert]) as [13_MO_A],	sum(C4G.[ 6.5-7 MO_Alert]) as [14_MO_A],		sum(C4G.[ 7-7.5 MO_Alert]) as [15_MO_A],
		sum(C4G.[ 7.5-8 MO_Alert]) as [16_MO_A],	sum(C4G.[ 8-8.5 MO_Alert]) as [17_MO_A],		sum(C4G.[ 8.5-9 MO_Alert]) as [18_MO_A],
		sum(C4G.[ 9-9.5 MO_Alert]) as [19_MO_A],	sum(C4G.[ 9.5-10 MO_Alert]) as [20_MO_A],		sum(C4G.[ 10-10.5 MO_Alert]) as [21_MO_A],
		sum(C4G.[ 10.5-11 MO_Alert]) as [22_MO_A],	sum(C4G.[ 11-11.5 MO_Alert]) as [23_MO_A],	sum(C4G.[ 11.5-12 MO_Alert]) as [24_MO_A],
		sum(C4G.[ 12-12.5 MO_Alert]) as [25_MO_A],	sum(C4G.[ 12.5-13 MO_Alert]) as [26_MO_A],	sum(C4G.[ 13-13.5 MO_Alert]) as [27_MO_A],
		sum(C4G.[ 13.5-14 MO_Alert]) as [28_MO_A],	sum(C4G.[ 14-14.5 MO_Alert]) as [29_MO_A],	sum(C4G.[ 14.5-15 MO_Alert]) as [30_MO_A],
		sum(C4G.[ 15-15.5 MO_Alert]) as [31_MO_A],	sum(C4G.[ 15.5-16 MO_Alert]) as [32_MO_A],	sum(C4G.[ 16-16.5 MO_Alert]) as [33_MO_A],
		sum(C4G.[ 16.5-17 MO_Alert]) as [34_MO_A],	sum(C4G.[ 17-17.5 MO_Alert]) as [35_MO_A],	sum(C4G.[ 17.5-18 MO_Alert]) as [36_MO_A],
		sum(C4G.[ 18-18.5 MO_Alert]) as [37_MO_A],	sum(C4G.[ 18.5-19 MO_Alert]) as [38_MO_A],	sum(C4G.[ 19-19.5 MO_Alert]) as [39_MO_A],
		sum(C4G.[ 19.5-20 MO_Alert]) as [40_MO_A],	sum(C4G.[ >20 MO_Alert]) as [41_MO_A],
		
		---------------------------------
		-- Rangos MT ALERTING:
		sum(C4G.[ 0-0.5 MT_Alert]) as [1_MT_A],	sum(C4G.[ 0.5-1 MT_Alert]) as [2_MT_A],		sum(C4G.[ 1-1.5 MT_Alert]) as [3_MT_A],
		sum(C4G.[ 1.5-2 MT_Alert]) as [4_MT_A],	sum(C4G.[ 2-2.5 MT_Alert]) as [5_MT_A],		sum(C4G.[ 2.5-3 MT_Alert]) as [6_MT_A],
		sum(C4G.[ 3-3.5 MT_Alert]) as [7_MT_A],	sum(C4G.[ 3.5-4 MT_Alert]) as [8_MT_A],		sum(C4G.[ 4-4.5 MT_Alert]) as [9_MT_A],
		sum(C4G.[ 4.5-5 MT_Alert]) as [10_MT_A],	sum(C4G.[ 5-5.5 MT_Alert]) as [11_MT_A],		sum(C4G.[ 5.5-6 MT_Alert]) as [12_MT_A],
		sum(C4G.[ 6-6.5 MT_Alert]) as [13_MT_A],	sum(C4G.[ 6.5-7 MT_Alert]) as [14_MT_A],		sum(C4G.[ 7-7.5 MT_Alert]) as [15_MT_A],
		sum(C4G.[ 7.5-8 MT_Alert]) as [16_MT_A],	sum(C4G.[ 8-8.5 MT_Alert]) as [17_MT_A],		sum(C4G.[ 8.5-9 MT_Alert]) as [18_MT_A],
		sum(C4G.[ 9-9.5 MT_Alert]) as [19_MT_A],	sum(C4G.[ 9.5-10 MT_Alert]) as [20_MT_A],		sum(C4G.[ 10-10.5 MT_Alert]) as [21_MT_A],
		sum(C4G.[ 10.5-11 MT_Alert]) as [22_MT_A],	sum(C4G.[ 11-11.5 MT_Alert]) as [23_MT_A],	sum(C4G.[ 11.5-12 MT_Alert]) as [24_MT_A],
		sum(C4G.[ 12-12.5 MT_Alert]) as [25_MT_A],	sum(C4G.[ 12.5-13 MT_Alert]) as [26_MT_A],	sum(C4G.[ 13-13.5 MT_Alert]) as [27_MT_A],
		sum(C4G.[ 13.5-14 MT_Alert]) as [28_MT_A],	sum(C4G.[ 14-14.5 MT_Alert]) as [29_MT_A],	sum(C4G.[ 14.5-15 MT_Alert]) as [30_MT_A],
		sum(C4G.[ 15-15.5 MT_Alert]) as [31_MT_A],	sum(C4G.[ 15.5-16 MT_Alert]) as [32_MT_A],	sum(C4G.[ 16-16.5 MT_Alert]) as [33_MT_A],
		sum(C4G.[ 16.5-17 MT_Alert]) as [34_MT_A],	sum(C4G.[ 17-17.5 MT_Alert]) as [35_MT_A],	sum(C4G.[ 17.5-18 MT_Alert]) as [36_MT_A],
		sum(C4G.[ 18-18.5 MT_Alert]) as [37_MT_A],	sum(C4G.[ 18.5-19 MT_Alert]) as [38_MT_A],	sum(C4G.[ 19-19.5 MT_Alert]) as [39_MT_A],
		sum(C4G.[ 19.5-20 MT_Alert]) as [40_MT_A],	sum(C4G.[ >20 MT_Alert]) as [41_MT_A],

		---------------------------------
		-- Rangos MOMT ALERTING:
		sum(C4G.[ 0-0.5 MOMT_Alert]) as [1_MOMT_A],	sum(C4G.[ 0.5-1 MOMT_Alert]) as [2_MOMT_A],	sum(C4G.[ 1-1.5 MOMT_Alert]) as [3_MOMT_A],
		sum(C4G.[ 1.5-2 MOMT_Alert]) as [4_MOMT_A],	sum(C4G.[ 2-2.5 MOMT_Alert]) as [5_MOMT_A],	sum(C4G.[ 2.5-3 MOMT_Alert]) as [6_MOMT_A],
		sum(C4G.[ 3-3.5 MOMT_Alert]) as [7_MOMT_A],	sum(C4G.[ 3.5-4 MOMT_Alert]) as [8_MOMT_A],	sum(C4G.[ 4-4.5 MOMT_Alert]) as [9_MOMT_A],
		sum(C4G.[ 4.5-5 MOMT_Alert]) as [10_MOMT_A],	sum(C4G.[ 5-5.5 MOMT_Alert]) as [11_MOMT_A],	sum(C4G.[ 5.5-6 MOMT_Alert]) as [12_MOMT_A],
		sum(C4G.[ 6-6.5 MOMT_Alert]) as [13_MOMT_A],	sum(C4G.[ 6.5-7 MOMT_Alert]) as [14_MOMT_A],	sum(C4G.[ 7-7.5 MOMT_Alert]) as [15_MOMT_A],
		sum(C4G.[ 7.5-8 MOMT_Alert]) as [16_MOMT_A],	sum(C4G.[ 8-8.5 MOMT_Alert]) as [17_MOMT_A],	sum(C4G.[ 8.5-9 MOMT_Alert]) as [18_MOMT_A],
		sum(C4G.[ 9-9.5 MOMT_Alert]) as [19_MOMT_A],	sum(C4G.[ 9.5-10 MOMT_Alert]) as [20_MOMT_A],	sum(C4G.[ 10-10.5 MOMT_Alert]) as [21_MOMT_A],
		sum(C4G.[ 10.5-11 MOMT_Alert]) as [22_MOMT_A],	sum(C4G.[ 11-11.5 MOMT_Alert]) as [23_MOMT_A],	sum(C4G.[ 11.5-12 MOMT_Alert]) as [24_MOMT_A],
		sum(C4G.[ 12-12.5 MOMT_Alert]) as [25_MOMT_A],	sum(C4G.[ 12.5-13 MOMT_Alert]) as [26_MOMT_A],	sum(C4G.[ 13-13.5 MOMT_Alert]) as [27_MOMT_A],
		sum(C4G.[ 13.5-14 MOMT_Alert]) as [28_MOMT_A],	sum(C4G.[ 14-14.5 MOMT_Alert]) as [29_MOMT_A],	sum(C4G.[ 14.5-15 MOMT_Alert]) as [30_MOMT_A],
		sum(C4G.[ 15-15.5 MOMT_Alert]) as [31_MOMT_A],	sum(C4G.[ 15.5-16 MOMT_Alert]) as [32_MOMT_A],	sum(C4G.[ 16-16.5 MOMT_Alert]) as [33_MOMT_A],
		sum(C4G.[ 16.5-17 MOMT_Alert]) as [34_MOMT_A],	sum(C4G.[ 17-17.5 MOMT_Alert]) as [35_MOMT_A],	sum(C4G.[ 17.5-18 MOMT_Alert]) as [36_MOMT_A],
		sum(C4G.[ 18-18.5 MOMT_Alert]) as [37_MOMT_A],	sum(C4G.[ 18.5-19 MOMT_Alert]) as [38_MOMT_A],	sum(C4G.[ 19-19.5 MOMT_Alert]) as [39_MOMT_A],
		sum(C4G.[ 19.5-20 MOMT_Alert]) as [40_MOMT_A],	sum(C4G.[ >20 MOMT_Alert]) as [41_MOMT_A],

		---------------------------------
		-- Rangos MO CONNECT:
		sum(C4G.[ 0-0.5 MO_Conn]) as [1_MO_C],	sum(C4G.[ 0.5-1 MO_Conn]) as [2_MO_C],	sum(C4G.[ 1-1.5 MO_Conn]) as [3_MO_C],
		sum(C4G.[ 1.5-2 MO_Conn]) as [4_MO_C],	sum(C4G.[ 2-2.5 MO_Conn]) as [5_MO_C],	sum(C4G.[ 2.5-3 MO_Conn]) as [6_MO_C],	
		sum(C4G.[ 3-3.5 MO_Conn]) as [7_MO_C],	sum(C4G.[ 3.5-4 MO_Conn]) as [8_MO_C],	sum(C4G.[ 4-4.5 MO_Conn]) as [9_MO_C],
		sum(C4G.[ 4.5-5 MO_Conn]) as [10_MO_C],	sum(C4G.[ 5-5.5 MO_Conn]) as [11_MO_C],	sum(C4G.[ 5.5-6 MO_Conn]) as [12_MO_C],
		sum(C4G.[ 6-6.5 MO_Conn]) as [13_MO_C],	sum(C4G.[ 6.5-7 MO_Conn]) as [14_MO_C],	sum(C4G.[ 7-7.5 MO_Conn]) as [15_MO_C],
		sum(C4G.[ 7.5-8 MO_Conn]) as [16_MO_C],	sum(C4G.[ 8-8.5 MO_Conn]) as [17_MO_C],	sum(C4G.[ 8.5-9 MO_Conn]) as [18_MO_C],
		sum(C4G.[ 9-9.5 MO_Conn]) as [19_MO_C],	sum(C4G.[ 9.5-10 MO_Conn]) as [20_MO_C],	sum(C4G.[ 10-10.5 MO_Conn]) as [21_MO_C],
		sum(C4G.[ 10.5-11 MO_Conn]) as [22_MO_C],	sum(C4G.[ 11-11.5 MO_Conn]) as [23_MO_C],	sum(C4G.[ 11.5-12 MO_Conn]) as [24_MO_C],
		sum(C4G.[ 12-12.5 MO_Conn]) as [25_MO_C],	sum(C4G.[ 12.5-13 MO_Conn]) as [26_MO_C],	sum(C4G.[ 13-13.5 MO_Conn]) as [27_MO_C],
		sum(C4G.[ 13.5-14 MO_Conn]) as [28_MO_C],	sum(C4G.[ 14-14.5 MO_Conn]) as [29_MO_C],	sum(C4G.[ 14.5-15 MO_Conn]) as [30_MO_C],
		sum(C4G.[ 15-15.5 MO_Conn]) as [31_MO_C],	sum(C4G.[ 15.5-16 MO_Conn]) as [32_MO_C],	sum(C4G.[ 16-16.5 MO_Conn]) as [33_MO_C],
		sum(C4G.[ 16.5-17 MO_Conn]) as [34_MO_C],	sum(C4G.[ 17-17.5 MO_Conn]) as [35_MO_C],	sum(C4G.[ 17.5-18 MO_Conn]) as [36_MO_C],
		sum(C4G.[ 18-18.5 MO_Conn]) as [37_MO_C],	sum(C4G.[ 18.5-19 MO_Conn]) as [38_MO_C],	sum(C4G.[ 19-19.5 MO_Conn]) as [39_MO_C],
		sum(C4G.[ 19.5-20 MO_Conn]) as [40_MO_C],	sum(C4G.[ >20 MO_Conn]) as [41_MO_C],

		---------------------------------
		-- Rangos MT CONNECT:
		sum(C4G.[ 0-0.5 MT_Conn]) as [1_MT_C],	sum(C4G.[ 0.5-1 MT_Conn]) as [2_MT_C],	sum(C4G.[ 1-1.5 MT_Conn]) as [3_MT_C],
		sum(C4G.[ 1.5-2 MT_Conn]) as [4_MT_C],	sum(C4G.[ 2-2.5 MT_Conn]) as [5_MT_C],	sum(C4G.[ 2.5-3 MT_Conn]) as [6_MT_C],
		sum(C4G.[ 3-3.5 MT_Conn]) as [7_MT_C],	sum(C4G.[ 3.5-4 MT_Conn]) as [8_MT_C],	sum(C4G.[ 4-4.5 MT_Conn]) as [9_MT_C],
		sum(C4G.[ 4.5-5 MT_Conn]) as [10_MT_C],	sum(C4G.[ 5-5.5 MT_Conn]) as [11_MT_C],	sum(C4G.[ 5.5-6 MT_Conn]) as [12_MT_C],
		sum(C4G.[ 6-6.5 MT_Conn]) as [13_MT_C],	sum(C4G.[ 6.5-7 MT_Conn]) as [14_MT_C],	sum(C4G.[ 7-7.5 MT_Conn]) as [15_MT_C],
		sum(C4G.[ 7.5-8 MT_Conn]) as [16_MT_C],	sum(C4G.[ 8-8.5 MT_Conn]) as [17_MT_C],	sum(C4G.[ 8.5-9 MT_Conn]) as [18_MT_C],
		sum(C4G.[ 9-9.5 MT_Conn]) as [19_MT_C],	sum(C4G.[ 9.5-10 MT_Conn]) as [20_MT_C],	sum(C4G.[ 10-10.5 MT_Conn]) as [21_MT_C],
		sum(C4G.[ 10.5-11 MT_Conn]) as [22_MT_C],	sum(C4G.[ 11-11.5 MT_Conn]) as [23_MT_C],	sum(C4G.[ 11.5-12 MT_Conn]) as [24_MT_C],
		sum(C4G.[ 12-12.5 MT_Conn]) as [25_MT_C],	sum(C4G.[ 12.5-13 MT_Conn]) as [26_MT_C],	sum(C4G.[ 13-13.5 MT_Conn]) as [27_MT_C],
		sum(C4G.[ 13.5-14 MT_Conn]) as [28_MT_C],	sum(C4G.[ 14-14.5 MT_Conn]) as [29_MT_C],	sum(C4G.[ 14.5-15 MT_Conn]) as [30_MT_C],
		sum(C4G.[ 15-15.5 MT_Conn]) as [31_MT_C],	sum(C4G.[ 15.5-16 MT_Conn]) as [32_MT_C],	sum(C4G.[ 16-16.5 MT_Conn]) as [33_MT_C],
		sum(C4G.[ 16.5-17 MT_Conn]) as [34_MT_C],	sum(C4G.[ 17-17.5 MT_Conn]) as [35_MT_C],	sum(C4G.[ 17.5-18 MT_Conn]) as [36_MT_C],
		sum(C4G.[ 18-18.5 MT_Conn]) as [37_MT_C],	sum(C4G.[ 18.5-19 MT_Conn]) as [38_MT_C],	sum(C4G.[ 19-19.5 MT_Conn]) as [39_MT_C],
		sum(C4G.[ 19.5-20 MT_Conn]) as [40_MT_C],	sum(C4G.[ >20 MT_Conn]) as [41_MT_C],

		---------------------------------
		-- Rangos MOMT CONNECT:
		sum(C4G.[ 0-0.5 MOMT_Conn]) as [1_MOMT_C],	sum(C4G.[ 0.5-1 MOMT_Conn]) as [2_MOMT_C],	sum(C4G.[ 1-1.5 MOMT_Conn]) as [3_MOMT_C],
		sum(C4G.[ 1.5-2 MOMT_Conn]) as [4_MOMT_C],	sum(C4G.[ 2-2.5 MOMT_Conn]) as [5_MOMT_C],	sum(C4G.[ 2.5-3 MOMT_Conn]) as [6_MOMT_C],
		sum(C4G.[ 3-3.5 MOMT_Conn]) as [7_MOMT_C],	sum(C4G.[ 3.5-4 MOMT_Conn]) as [8_MOMT_C],	sum(C4G.[ 4-4.5 MOMT_Conn]) as [9_MOMT_C],
		sum(C4G.[ 4.5-5 MOMT_Conn]) as [10_MOMT_C],	sum(C4G.[ 5-5.5 MOMT_Conn]) as [11_MOMT_C],	sum(C4G.[ 5.5-6 MOMT_Conn]) as [12_MOMT_C],
		sum(C4G.[ 6-6.5 MOMT_Conn]) as [13_MOMT_C],	sum(C4G.[ 6.5-7 MOMT_Conn]) as [14_MOMT_C],	sum(C4G.[ 7-7.5 MOMT_Conn]) as [15_MOMT_C],
		sum(C4G.[ 7.5-8 MOMT_Conn]) as [16_MOMT_C],	sum(C4G.[ 8-8.5 MOMT_Conn]) as [17_MOMT_C],	sum(C4G.[ 8.5-9 MOMT_Conn]) as [18_MOMT_C],
		sum(C4G.[ 9-9.5 MOMT_Conn]) as [19_MOMT_C],	sum(C4G.[ 9.5-10 MOMT_Conn]) as [20_MOMT_C],	sum(C4G.[ 10-10.5 MOMT_Conn]) as [21_MOMT_C],
		sum(C4G.[ 10.5-11 MOMT_Conn]) as [22_MOMT_C],	sum(C4G.[ 11-11.5 MOMT_Conn]) as [23_MOMT_C],	sum(C4G.[ 11.5-12 MOMT_Conn]) as [24_MOMT_C],
		sum(C4G.[ 12-12.5 MOMT_Conn]) as [25_MOMT_C],	sum(C4G.[ 12.5-13 MOMT_Conn]) as [26_MOMT_C],	sum(C4G.[ 13-13.5 MOMT_Conn]) as [27_MOMT_C],
		sum(C4G.[ 13.5-14 MOMT_Conn]) as [28_MOMT_C],	sum(C4G.[ 14-14.5 MOMT_Conn]) as [29_MOMT_C],	sum(C4G.[ 14.5-15 MOMT_Conn]) as [30_MOMT_C],
		sum(C4G.[ 15-15.5 MOMT_Conn]) as [31_MOMT_C],	sum(C4G.[ 15.5-16 MOMT_Conn]) as [32_MOMT_C],	sum(C4G.[ 16-16.5 MOMT_Conn]) as [33_MOMT_C],
		sum(C4G.[ 16.5-17 MOMT_Conn]) as [34_MOMT_C],	sum(C4G.[ 17-17.5 MOMT_Conn]) as [35_MOMT_C],	sum(C4G.[ 17.5-18 MOMT_Conn]) as [36_MOMT_C],
		sum(C4G.[ 18-18.5 MOMT_Conn]) as [37_MOMT_C],	sum(C4G.[ 18.5-19 MOMT_Conn]) as [38_MOMT_C],	sum(C4G.[ 19-19.5 MOMT_Conn]) as [39_MOMT_C],
		sum(C4G.[ 19.5-20 MOMT_Conn]) as [40_MOMT_C],	sum(C4G.[ >20 MOMT_Conn]) as [41_MOMT_C],

		---------------------------------
		--cst.Region_VF as Region_Road_VF, cst.Region_OSP as Region_Road_OSP,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]
	
	from [AGGRVoice4G_Road].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls] cst
			left outer join [AGGRVoice4G_Road].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls_4G] C4G on (isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')=isnull(C4G.parcel,'0.00000 Long, 0.00000 Lat') and cst.mnc=C4G.mnc and cst.Date_Reporting=C4G.Date_Reporting and cst.entidad=C4G.entidad and cst.Aggr_Type=C4G.Aggr_Type and cst.Report_Type=C4G.Report_Type and cst.meas_round=C4G.meas_round) 
		,[AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,cst.mnc,cst.meas_round,cst.Date_Reporting,cst.Week_Reporting,cst.entidad,cst.Report_Type,cst.aggr_type, cst.calltype,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]--, cst.Region_VF, cst.Region_OSP

	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 3.2 CST 4GOnly y 4GOnly_Road', getdate()

	--------------------------------------------------------------------------------------
	/*		3.3	Se añade info VOLTE - ALL, 4G, RealVOLTE, 3G							*/
	-------------------------------------------------------------------------------------- 
	print '3.3 CST VOLTE - ALL, 4G, RealVOLTE, 3G'
	-----------	
	-- VOLTE ALL:
	insert into _RI_Voice_cst
	select 
		volte.calltype as Calltype,
		p.codigo_ine, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment, volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE ALL Road' 
			else 'VOLTE ALL' end as meas_Tech, 1 as info_available,volte.entidad as vf_entity,volte.Report_Type,volte.aggr_type,
    
		0.001*(1000.0*SUM(volte.[CST_MOMT_Alerting]*(volte.[Calls_AVG_ALERT_MO]+volte.[Calls_AVG_ALERT_MT]))) as CST_ALERTING_NUM,
		0.001*(1000.0*SUM(volte.[CST_MOMT_Connect]*(volte.[Calls_AVG_CONNECT_MO]+volte.[Calls_AVG_CONNECT_MT]))) as CST_CONNECT_NUM,

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(volte.[Calls_AVG_ALERT_MO]) as CST_MO_AL_samples,
		sum(volte.[Calls_AVG_ALERT_MT]) as CST_MT_AL_samples,
		sum(volte.[Calls_AVG_CONNECT_MO]) as CST_MO_CO_Samples,
		sum(volte.[Calls_AVG_CONNECT_MT]) as CST_MT_CO_Samples,

		0.001*(1000.0*SUM(volte.[CST_MO_Alerting]*volte.[Calls_AVG_ALERT_MO])) as CST_MO_AL_NUM,
		0.001*(1000.0*SUM(volte.[CST_MT_Alerting]*volte.[Calls_AVG_ALERT_MT])) as CST_MT_AL_NUM,
		0.001*(1000.0*SUM(volte.[CST_MO_Connect]*volte.[Calls_AVG_CONNECT_MO])) as CST_MO_CO_NUM,
		0.001*(1000.0*SUM(volte.[CST_MT_Connect]*volte.[Calls_AVG_CONNECT_MT])) as CST_MT_CO_NUM,

		---------------------------------
		-- Rangos MO ALERTING:
		sum(volte.[ 0-0.5 MO_Alert]) as [1_MO_A],	sum(volte.[ 0.5-1 MO_Alert]) as [2_MO_A],		sum(volte.[ 1-1.5 MO_Alert]) as [3_MO_A],
		sum(volte.[ 1.5-2 MO_Alert]) as [4_MO_A],	sum(volte.[ 2-2.5 MO_Alert]) as [5_MO_A],		sum(volte.[ 2.5-3 MO_Alert]) as [6_MO_A],
		sum(volte.[ 3-3.5 MO_Alert]) as [7_MO_A],	sum(volte.[ 3.5-4 MO_Alert]) as [8_MO_A],		sum(volte.[ 4-4.5 MO_Alert]) as [9_MO_A],
		sum(volte.[ 4.5-5 MO_Alert]) as [10_MO_A],	sum(volte.[ 5-5.5 MO_Alert]) as [11_MO_A],		sum(volte.[ 5.5-6 MO_Alert]) as [12_MO_A],
		sum(volte.[ 6-6.5 MO_Alert]) as [13_MO_A],	sum(volte.[ 6.5-7 MO_Alert]) as [14_MO_A],		sum(volte.[ 7-7.5 MO_Alert]) as [15_MO_A],
		sum(volte.[ 7.5-8 MO_Alert]) as [16_MO_A],	sum(volte.[ 8-8.5 MO_Alert]) as [17_MO_A],		sum(volte.[ 8.5-9 MO_Alert]) as [18_MO_A],
		sum(volte.[ 9-9.5 MO_Alert]) as [19_MO_A],	sum(volte.[ 9.5-10 MO_Alert]) as [20_MO_A],		sum(volte.[ 10-10.5 MO_Alert]) as [21_MO_A],
		sum(volte.[ 10.5-11 MO_Alert]) as [22_MO_A],	sum(volte.[ 11-11.5 MO_Alert]) as [23_MO_A],	sum(volte.[ 11.5-12 MO_Alert]) as [24_MO_A],
		sum(volte.[ 12-12.5 MO_Alert]) as [25_MO_A],	sum(volte.[ 12.5-13 MO_Alert]) as [26_MO_A],	sum(volte.[ 13-13.5 MO_Alert]) as [27_MO_A],
		sum(volte.[ 13.5-14 MO_Alert]) as [28_MO_A],	sum(volte.[ 14-14.5 MO_Alert]) as [29_MO_A],	sum(volte.[ 14.5-15 MO_Alert]) as [30_MO_A],
		sum(volte.[ 15-15.5 MO_Alert]) as [31_MO_A],	sum(volte.[ 15.5-16 MO_Alert]) as [32_MO_A],	sum(volte.[ 16-16.5 MO_Alert]) as [33_MO_A],
		sum(volte.[ 16.5-17 MO_Alert]) as [34_MO_A],	sum(volte.[ 17-17.5 MO_Alert]) as [35_MO_A],	sum(volte.[ 17.5-18 MO_Alert]) as [36_MO_A],
		sum(volte.[ 18-18.5 MO_Alert]) as [37_MO_A],	sum(volte.[ 18.5-19 MO_Alert]) as [38_MO_A],	sum(volte.[ 19-19.5 MO_Alert]) as [39_MO_A],
		sum(volte.[ 19.5-20 MO_Alert]) as [40_MO_A],	sum(volte.[ >20 MO_Alert]) as [41_MO_A],
		
		---------------------------------
		-- Rangos MT ALERTING:
		sum(volte.[ 0-0.5 MT_Alert]) as [1_MT_A],	sum(volte.[ 0.5-1 MT_Alert]) as [2_MT_A],		sum(volte.[ 1-1.5 MT_Alert]) as [3_MT_A],
		sum(volte.[ 1.5-2 MT_Alert]) as [4_MT_A],	sum(volte.[ 2-2.5 MT_Alert]) as [5_MT_A],		sum(volte.[ 2.5-3 MT_Alert]) as [6_MT_A],
		sum(volte.[ 3-3.5 MT_Alert]) as [7_MT_A],	sum(volte.[ 3.5-4 MT_Alert]) as [8_MT_A],		sum(volte.[ 4-4.5 MT_Alert]) as [9_MT_A],
		sum(volte.[ 4.5-5 MT_Alert]) as [10_MT_A],	sum(volte.[ 5-5.5 MT_Alert]) as [11_MT_A],		sum(volte.[ 5.5-6 MT_Alert]) as [12_MT_A],
		sum(volte.[ 6-6.5 MT_Alert]) as [13_MT_A],	sum(volte.[ 6.5-7 MT_Alert]) as [14_MT_A],		sum(volte.[ 7-7.5 MT_Alert]) as [15_MT_A],
		sum(volte.[ 7.5-8 MT_Alert]) as [16_MT_A],	sum(volte.[ 8-8.5 MT_Alert]) as [17_MT_A],		sum(volte.[ 8.5-9 MT_Alert]) as [18_MT_A],
		sum(volte.[ 9-9.5 MT_Alert]) as [19_MT_A],	sum(volte.[ 9.5-10 MT_Alert]) as [20_MT_A],		sum(volte.[ 10-10.5 MT_Alert]) as [21_MT_A],
		sum(volte.[ 10.5-11 MT_Alert]) as [22_MT_A],	sum(volte.[ 11-11.5 MT_Alert]) as [23_MT_A],	sum(volte.[ 11.5-12 MT_Alert]) as [24_MT_A],
		sum(volte.[ 12-12.5 MT_Alert]) as [25_MT_A],	sum(volte.[ 12.5-13 MT_Alert]) as [26_MT_A],	sum(volte.[ 13-13.5 MT_Alert]) as [27_MT_A],
		sum(volte.[ 13.5-14 MT_Alert]) as [28_MT_A],	sum(volte.[ 14-14.5 MT_Alert]) as [29_MT_A],	sum(volte.[ 14.5-15 MT_Alert]) as [30_MT_A],
		sum(volte.[ 15-15.5 MT_Alert]) as [31_MT_A],	sum(volte.[ 15.5-16 MT_Alert]) as [32_MT_A],	sum(volte.[ 16-16.5 MT_Alert]) as [33_MT_A],
		sum(volte.[ 16.5-17 MT_Alert]) as [34_MT_A],	sum(volte.[ 17-17.5 MT_Alert]) as [35_MT_A],	sum(volte.[ 17.5-18 MT_Alert]) as [36_MT_A],
		sum(volte.[ 18-18.5 MT_Alert]) as [37_MT_A],	sum(volte.[ 18.5-19 MT_Alert]) as [38_MT_A],	sum(volte.[ 19-19.5 MT_Alert]) as [39_MT_A],
		sum(volte.[ 19.5-20 MT_Alert]) as [40_MT_A],	sum(volte.[ >20 MT_Alert]) as [41_MT_A],

		---------------------------------
		-- Rangos MOMT ALERTING:
		sum(volte.[ 0-0.5 MOMT_Alert]) as [1_MOMT_A],	sum(volte.[ 0.5-1 MOMT_Alert]) as [2_MOMT_A],	sum(volte.[ 1-1.5 MOMT_Alert]) as [3_MOMT_A],
		sum(volte.[ 1.5-2 MOMT_Alert]) as [4_MOMT_A],	sum(volte.[ 2-2.5 MOMT_Alert]) as [5_MOMT_A],	sum(volte.[ 2.5-3 MOMT_Alert]) as [6_MOMT_A],
		sum(volte.[ 3-3.5 MOMT_Alert]) as [7_MOMT_A],	sum(volte.[ 3.5-4 MOMT_Alert]) as [8_MOMT_A],	sum(volte.[ 4-4.5 MOMT_Alert]) as [9_MOMT_A],
		sum(volte.[ 4.5-5 MOMT_Alert]) as [10_MOMT_A],	sum(volte.[ 5-5.5 MOMT_Alert]) as [11_MOMT_A],	sum(volte.[ 5.5-6 MOMT_Alert]) as [12_MOMT_A],
		sum(volte.[ 6-6.5 MOMT_Alert]) as [13_MOMT_A],	sum(volte.[ 6.5-7 MOMT_Alert]) as [14_MOMT_A],	sum(volte.[ 7-7.5 MOMT_Alert]) as [15_MOMT_A],
		sum(volte.[ 7.5-8 MOMT_Alert]) as [16_MOMT_A],	sum(volte.[ 8-8.5 MOMT_Alert]) as [17_MOMT_A],	sum(volte.[ 8.5-9 MOMT_Alert]) as [18_MOMT_A],
		sum(volte.[ 9-9.5 MOMT_Alert]) as [19_MOMT_A],	sum(volte.[ 9.5-10 MOMT_Alert]) as [20_MOMT_A],	sum(volte.[ 10-10.5 MOMT_Alert]) as [21_MOMT_A],
		sum(volte.[ 10.5-11 MOMT_Alert]) as [22_MOMT_A],	sum(volte.[ 11-11.5 MOMT_Alert]) as [23_MOMT_A],	sum(volte.[ 11.5-12 MOMT_Alert]) as [24_MOMT_A],
		sum(volte.[ 12-12.5 MOMT_Alert]) as [25_MOMT_A],	sum(volte.[ 12.5-13 MOMT_Alert]) as [26_MOMT_A],	sum(volte.[ 13-13.5 MOMT_Alert]) as [27_MOMT_A],
		sum(volte.[ 13.5-14 MOMT_Alert]) as [28_MOMT_A],	sum(volte.[ 14-14.5 MOMT_Alert]) as [29_MOMT_A],	sum(volte.[ 14.5-15 MOMT_Alert]) as [30_MOMT_A],
		sum(volte.[ 15-15.5 MOMT_Alert]) as [31_MOMT_A],	sum(volte.[ 15.5-16 MOMT_Alert]) as [32_MOMT_A],	sum(volte.[ 16-16.5 MOMT_Alert]) as [33_MOMT_A],
		sum(volte.[ 16.5-17 MOMT_Alert]) as [34_MOMT_A],	sum(volte.[ 17-17.5 MOMT_Alert]) as [35_MOMT_A],	sum(volte.[ 17.5-18 MOMT_Alert]) as [36_MOMT_A],
		sum(volte.[ 18-18.5 MOMT_Alert]) as [37_MOMT_A],	sum(volte.[ 18.5-19 MOMT_Alert]) as [38_MOMT_A],	sum(volte.[ 19-19.5 MOMT_Alert]) as [39_MOMT_A],
		sum(volte.[ 19.5-20 MOMT_Alert]) as [40_MOMT_A],	sum(volte.[ >20 MOMT_Alert]) as [41_MOMT_A],

		---------------------------------
		-- Rangos MO CONNECT:
		sum(volte.[ 0-0.5 MO_Conn]) as [1_MO_C],	sum(volte.[ 0.5-1 MO_Conn]) as [2_MO_C],	sum(volte.[ 1-1.5 MO_Conn]) as [3_MO_C],
		sum(volte.[ 1.5-2 MO_Conn]) as [4_MO_C],	sum(volte.[ 2-2.5 MO_Conn]) as [5_MO_C],	sum(volte.[ 2.5-3 MO_Conn]) as [6_MO_C],	
		sum(volte.[ 3-3.5 MO_Conn]) as [7_MO_C],	sum(volte.[ 3.5-4 MO_Conn]) as [8_MO_C],	sum(volte.[ 4-4.5 MO_Conn]) as [9_MO_C],
		sum(volte.[ 4.5-5 MO_Conn]) as [10_MO_C],	sum(volte.[ 5-5.5 MO_Conn]) as [11_MO_C],	sum(volte.[ 5.5-6 MO_Conn]) as [12_MO_C],
		sum(volte.[ 6-6.5 MO_Conn]) as [13_MO_C],	sum(volte.[ 6.5-7 MO_Conn]) as [14_MO_C],	sum(volte.[ 7-7.5 MO_Conn]) as [15_MO_C],
		sum(volte.[ 7.5-8 MO_Conn]) as [16_MO_C],	sum(volte.[ 8-8.5 MO_Conn]) as [17_MO_C],	sum(volte.[ 8.5-9 MO_Conn]) as [18_MO_C],
		sum(volte.[ 9-9.5 MO_Conn]) as [19_MO_C],	sum(volte.[ 9.5-10 MO_Conn]) as [20_MO_C],	sum(volte.[ 10-10.5 MO_Conn]) as [21_MO_C],
		sum(volte.[ 10.5-11 MO_Conn]) as [22_MO_C],	sum(volte.[ 11-11.5 MO_Conn]) as [23_MO_C],	sum(volte.[ 11.5-12 MO_Conn]) as [24_MO_C],
		sum(volte.[ 12-12.5 MO_Conn]) as [25_MO_C],	sum(volte.[ 12.5-13 MO_Conn]) as [26_MO_C],	sum(volte.[ 13-13.5 MO_Conn]) as [27_MO_C],
		sum(volte.[ 13.5-14 MO_Conn]) as [28_MO_C],	sum(volte.[ 14-14.5 MO_Conn]) as [29_MO_C],	sum(volte.[ 14.5-15 MO_Conn]) as [30_MO_C],
		sum(volte.[ 15-15.5 MO_Conn]) as [31_MO_C],	sum(volte.[ 15.5-16 MO_Conn]) as [32_MO_C],	sum(volte.[ 16-16.5 MO_Conn]) as [33_MO_C],
		sum(volte.[ 16.5-17 MO_Conn]) as [34_MO_C],	sum(volte.[ 17-17.5 MO_Conn]) as [35_MO_C],	sum(volte.[ 17.5-18 MO_Conn]) as [36_MO_C],
		sum(volte.[ 18-18.5 MO_Conn]) as [37_MO_C],	sum(volte.[ 18.5-19 MO_Conn]) as [38_MO_C],	sum(volte.[ 19-19.5 MO_Conn]) as [39_MO_C],
		sum(volte.[ 19.5-20 MO_Conn]) as [40_MO_C],	sum(volte.[ >20 MO_Conn]) as [41_MO_C],

		---------------------------------
		-- Rangos MT CONNECT:
		sum(volte.[ 0-0.5 MT_Conn]) as [1_MT_C],	sum(volte.[ 0.5-1 MT_Conn]) as [2_MT_C],	sum(volte.[ 1-1.5 MT_Conn]) as [3_MT_C],
		sum(volte.[ 1.5-2 MT_Conn]) as [4_MT_C],	sum(volte.[ 2-2.5 MT_Conn]) as [5_MT_C],	sum(volte.[ 2.5-3 MT_Conn]) as [6_MT_C],
		sum(volte.[ 3-3.5 MT_Conn]) as [7_MT_C],	sum(volte.[ 3.5-4 MT_Conn]) as [8_MT_C],	sum(volte.[ 4-4.5 MT_Conn]) as [9_MT_C],
		sum(volte.[ 4.5-5 MT_Conn]) as [10_MT_C],	sum(volte.[ 5-5.5 MT_Conn]) as [11_MT_C],	sum(volte.[ 5.5-6 MT_Conn]) as [12_MT_C],
		sum(volte.[ 6-6.5 MT_Conn]) as [13_MT_C],	sum(volte.[ 6.5-7 MT_Conn]) as [14_MT_C],	sum(volte.[ 7-7.5 MT_Conn]) as [15_MT_C],
		sum(volte.[ 7.5-8 MT_Conn]) as [16_MT_C],	sum(volte.[ 8-8.5 MT_Conn]) as [17_MT_C],	sum(volte.[ 8.5-9 MT_Conn]) as [18_MT_C],
		sum(volte.[ 9-9.5 MT_Conn]) as [19_MT_C],	sum(volte.[ 9.5-10 MT_Conn]) as [20_MT_C],	sum(volte.[ 10-10.5 MT_Conn]) as [21_MT_C],
		sum(volte.[ 10.5-11 MT_Conn]) as [22_MT_C],	sum(volte.[ 11-11.5 MT_Conn]) as [23_MT_C],	sum(volte.[ 11.5-12 MT_Conn]) as [24_MT_C],
		sum(volte.[ 12-12.5 MT_Conn]) as [25_MT_C],	sum(volte.[ 12.5-13 MT_Conn]) as [26_MT_C],	sum(volte.[ 13-13.5 MT_Conn]) as [27_MT_C],
		sum(volte.[ 13.5-14 MT_Conn]) as [28_MT_C],	sum(volte.[ 14-14.5 MT_Conn]) as [29_MT_C],	sum(volte.[ 14.5-15 MT_Conn]) as [30_MT_C],
		sum(volte.[ 15-15.5 MT_Conn]) as [31_MT_C],	sum(volte.[ 15.5-16 MT_Conn]) as [32_MT_C],	sum(volte.[ 16-16.5 MT_Conn]) as [33_MT_C],
		sum(volte.[ 16.5-17 MT_Conn]) as [34_MT_C],	sum(volte.[ 17-17.5 MT_Conn]) as [35_MT_C],	sum(volte.[ 17.5-18 MT_Conn]) as [36_MT_C],
		sum(volte.[ 18-18.5 MT_Conn]) as [37_MT_C],	sum(volte.[ 18.5-19 MT_Conn]) as [38_MT_C],	sum(volte.[ 19-19.5 MT_Conn]) as [39_MT_C],
		sum(volte.[ 19.5-20 MT_Conn]) as [40_MT_C],	sum(volte.[ >20 MT_Conn]) as [41_MT_C],

		---------------------------------
		-- Rangos MOMT CONNECT:
		sum(volte.[ 0-0.5 MOMT_Conn]) as [1_MOMT_C],	sum(volte.[ 0.5-1 MOMT_Conn]) as [2_MOMT_C],	sum(volte.[ 1-1.5 MOMT_Conn]) as [3_MOMT_C],
		sum(volte.[ 1.5-2 MOMT_Conn]) as [4_MOMT_C],	sum(volte.[ 2-2.5 MOMT_Conn]) as [5_MOMT_C],	sum(volte.[ 2.5-3 MOMT_Conn]) as [6_MOMT_C],
		sum(volte.[ 3-3.5 MOMT_Conn]) as [7_MOMT_C],	sum(volte.[ 3.5-4 MOMT_Conn]) as [8_MOMT_C],	sum(volte.[ 4-4.5 MOMT_Conn]) as [9_MOMT_C],
		sum(volte.[ 4.5-5 MOMT_Conn]) as [10_MOMT_C],	sum(volte.[ 5-5.5 MOMT_Conn]) as [11_MOMT_C],	sum(volte.[ 5.5-6 MOMT_Conn]) as [12_MOMT_C],
		sum(volte.[ 6-6.5 MOMT_Conn]) as [13_MOMT_C],	sum(volte.[ 6.5-7 MOMT_Conn]) as [14_MOMT_C],	sum(volte.[ 7-7.5 MOMT_Conn]) as [15_MOMT_C],
		sum(volte.[ 7.5-8 MOMT_Conn]) as [16_MOMT_C],	sum(volte.[ 8-8.5 MOMT_Conn]) as [17_MOMT_C],	sum(volte.[ 8.5-9 MOMT_Conn]) as [18_MOMT_C],
		sum(volte.[ 9-9.5 MOMT_Conn]) as [19_MOMT_C],	sum(volte.[ 9.5-10 MOMT_Conn]) as [20_MOMT_C],	sum(volte.[ 10-10.5 MOMT_Conn]) as [21_MOMT_C],
		sum(volte.[ 10.5-11 MOMT_Conn]) as [22_MOMT_C],	sum(volte.[ 11-11.5 MOMT_Conn]) as [23_MOMT_C],	sum(volte.[ 11.5-12 MOMT_Conn]) as [24_MOMT_C],
		sum(volte.[ 12-12.5 MOMT_Conn]) as [25_MOMT_C],	sum(volte.[ 12.5-13 MOMT_Conn]) as [26_MOMT_C],	sum(volte.[ 13-13.5 MOMT_Conn]) as [27_MOMT_C],
		sum(volte.[ 13.5-14 MOMT_Conn]) as [28_MOMT_C],	sum(volte.[ 14-14.5 MOMT_Conn]) as [29_MOMT_C],	sum(volte.[ 14.5-15 MOMT_Conn]) as [30_MOMT_C],
		sum(volte.[ 15-15.5 MOMT_Conn]) as [31_MOMT_C],	sum(volte.[ 15.5-16 MOMT_Conn]) as [32_MOMT_C],	sum(volte.[ 16-16.5 MOMT_Conn]) as [33_MOMT_C],
		sum(volte.[ 16.5-17 MOMT_Conn]) as [34_MOMT_C],	sum(volte.[ 17-17.5 MOMT_Conn]) as [35_MOMT_C],	sum(volte.[ 17.5-18 MOMT_Conn]) as [36_MOMT_C],
		sum(volte.[ 18-18.5 MOMT_Conn]) as [37_MOMT_C],	sum(volte.[ 18.5-19 MOMT_Conn]) as [38_MOMT_C],	sum(volte.[ 19-19.5 MOMT_Conn]) as [39_MOMT_C],
		sum(volte.[ 19.5-20 MOMT_Conn]) as [40_MOMT_C],	sum(volte.[ >20 MOMT_Conn]) as [41_MOMT_C],

		---------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]	

	from [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls] volte, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,  
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end, case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE ALL Road' 
			else 'VOLTE ALL' end, volte.mnc,volte.meas_round,volte.Date_Reporting,volte.Week_Reporting,volte.entidad,volte.Report_Type,volte.aggr_type,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	---------
	-- VOLTE 4G:
	insert into _RI_Voice_cst
	select 
		volte.calltype as Calltype,
		p.codigo_ine,  
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment,volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 4G Road' 
			else 'VOLTE 4G' end as meas_Tech, 1 as info_available,volte.entidad as vf_entity,volte.Report_Type,volte.aggr_type,
    
		0.001*(1000.0*SUM(volte4G.[CST_MOMT_Alerting]*(volte4G.[Calls_AVG_ALERT_MO]+volte4G.[Calls_AVG_ALERT_MT]))) as CST_ALERTING_NUM,
		0.001*(1000.0*SUM(volte4G.[CST_MOMT_Connect]*(volte4G.[Calls_AVG_CONNECT_MO]+volte4G.[Calls_AVG_CONNECT_MT]))) as CST_CONNECT_NUM,

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(volte4G.[Calls_AVG_ALERT_MO]) as CST_MO_AL_samples,
		sum(volte4G.[Calls_AVG_ALERT_MT]) as CST_MT_AL_samples,
		sum(volte4G.[Calls_AVG_CONNECT_MO]) as CST_MO_CO_Samples,
		sum(volte4G.[Calls_AVG_CONNECT_MT]) as CST_MT_CO_Samples,

		0.001*(1000.0*SUM(volte4G.[CST_MO_Alerting]*volte4G.[Calls_AVG_ALERT_MO])) as CST_MO_AL_NUM,
		0.001*(1000.0*SUM(volte4G.[CST_MT_Alerting]*volte4G.[Calls_AVG_ALERT_MT])) as CST_MT_AL_NUM,
		0.001*(1000.0*SUM(volte4G.[CST_MO_Connect]*volte4G.[Calls_AVG_CONNECT_MO])) as CST_MO_CO_NUM,
		0.001*(1000.0*SUM(volte4G.[CST_MT_Connect]*volte4G.[Calls_AVG_CONNECT_MT])) as CST_MT_CO_NUM,

		---------------------------------
		-- Rangos MO ALERTING:
		sum(volte4G.[ 0-0.5 MO_Alert]) as [1_MO_A],	sum(volte4G.[ 0.5-1 MO_Alert]) as [2_MO_A],		sum(volte4G.[ 1-1.5 MO_Alert]) as [3_MO_A],
		sum(volte4G.[ 1.5-2 MO_Alert]) as [4_MO_A],	sum(volte4G.[ 2-2.5 MO_Alert]) as [5_MO_A],		sum(volte4G.[ 2.5-3 MO_Alert]) as [6_MO_A],
		sum(volte4G.[ 3-3.5 MO_Alert]) as [7_MO_A],	sum(volte4G.[ 3.5-4 MO_Alert]) as [8_MO_A],		sum(volte4G.[ 4-4.5 MO_Alert]) as [9_MO_A],
		sum(volte4G.[ 4.5-5 MO_Alert]) as [10_MO_A],	sum(volte4G.[ 5-5.5 MO_Alert]) as [11_MO_A],		sum(volte4G.[ 5.5-6 MO_Alert]) as [12_MO_A],
		sum(volte4G.[ 6-6.5 MO_Alert]) as [13_MO_A],	sum(volte4G.[ 6.5-7 MO_Alert]) as [14_MO_A],		sum(volte4G.[ 7-7.5 MO_Alert]) as [15_MO_A],
		sum(volte4G.[ 7.5-8 MO_Alert]) as [16_MO_A],	sum(volte4G.[ 8-8.5 MO_Alert]) as [17_MO_A],		sum(volte4G.[ 8.5-9 MO_Alert]) as [18_MO_A],
		sum(volte4G.[ 9-9.5 MO_Alert]) as [19_MO_A],	sum(volte4G.[ 9.5-10 MO_Alert]) as [20_MO_A],		sum(volte4G.[ 10-10.5 MO_Alert]) as [21_MO_A],
		sum(volte4G.[ 10.5-11 MO_Alert]) as [22_MO_A],	sum(volte4G.[ 11-11.5 MO_Alert]) as [23_MO_A],	sum(volte4G.[ 11.5-12 MO_Alert]) as [24_MO_A],
		sum(volte4G.[ 12-12.5 MO_Alert]) as [25_MO_A],	sum(volte4G.[ 12.5-13 MO_Alert]) as [26_MO_A],	sum(volte4G.[ 13-13.5 MO_Alert]) as [27_MO_A],
		sum(volte4G.[ 13.5-14 MO_Alert]) as [28_MO_A],	sum(volte4G.[ 14-14.5 MO_Alert]) as [29_MO_A],	sum(volte4G.[ 14.5-15 MO_Alert]) as [30_MO_A],
		sum(volte4G.[ 15-15.5 MO_Alert]) as [31_MO_A],	sum(volte4G.[ 15.5-16 MO_Alert]) as [32_MO_A],	sum(volte4G.[ 16-16.5 MO_Alert]) as [33_MO_A],
		sum(volte4G.[ 16.5-17 MO_Alert]) as [34_MO_A],	sum(volte4G.[ 17-17.5 MO_Alert]) as [35_MO_A],	sum(volte4G.[ 17.5-18 MO_Alert]) as [36_MO_A],
		sum(volte4G.[ 18-18.5 MO_Alert]) as [37_MO_A],	sum(volte4G.[ 18.5-19 MO_Alert]) as [38_MO_A],	sum(volte4G.[ 19-19.5 MO_Alert]) as [39_MO_A],
		sum(volte4G.[ 19.5-20 MO_Alert]) as [40_MO_A],	sum(volte4G.[ >20 MO_Alert]) as [41_MO_A],
		
		---------------------------------
		-- Rangos MT ALERTING:
		sum(volte4G.[ 0-0.5 MT_Alert]) as [1_MT_A],	sum(volte4G.[ 0.5-1 MT_Alert]) as [2_MT_A],		sum(volte4G.[ 1-1.5 MT_Alert]) as [3_MT_A],
		sum(volte4G.[ 1.5-2 MT_Alert]) as [4_MT_A],	sum(volte4G.[ 2-2.5 MT_Alert]) as [5_MT_A],		sum(volte4G.[ 2.5-3 MT_Alert]) as [6_MT_A],
		sum(volte4G.[ 3-3.5 MT_Alert]) as [7_MT_A],	sum(volte4G.[ 3.5-4 MT_Alert]) as [8_MT_A],		sum(volte4G.[ 4-4.5 MT_Alert]) as [9_MT_A],
		sum(volte4G.[ 4.5-5 MT_Alert]) as [10_MT_A],	sum(volte4G.[ 5-5.5 MT_Alert]) as [11_MT_A],		sum(volte4G.[ 5.5-6 MT_Alert]) as [12_MT_A],
		sum(volte4G.[ 6-6.5 MT_Alert]) as [13_MT_A],	sum(volte4G.[ 6.5-7 MT_Alert]) as [14_MT_A],		sum(volte4G.[ 7-7.5 MT_Alert]) as [15_MT_A],
		sum(volte4G.[ 7.5-8 MT_Alert]) as [16_MT_A],	sum(volte4G.[ 8-8.5 MT_Alert]) as [17_MT_A],		sum(volte4G.[ 8.5-9 MT_Alert]) as [18_MT_A],
		sum(volte4G.[ 9-9.5 MT_Alert]) as [19_MT_A],	sum(volte4G.[ 9.5-10 MT_Alert]) as [20_MT_A],		sum(volte4G.[ 10-10.5 MT_Alert]) as [21_MT_A],
		sum(volte4G.[ 10.5-11 MT_Alert]) as [22_MT_A],	sum(volte4G.[ 11-11.5 MT_Alert]) as [23_MT_A],	sum(volte4G.[ 11.5-12 MT_Alert]) as [24_MT_A],
		sum(volte4G.[ 12-12.5 MT_Alert]) as [25_MT_A],	sum(volte4G.[ 12.5-13 MT_Alert]) as [26_MT_A],	sum(volte4G.[ 13-13.5 MT_Alert]) as [27_MT_A],
		sum(volte4G.[ 13.5-14 MT_Alert]) as [28_MT_A],	sum(volte4G.[ 14-14.5 MT_Alert]) as [29_MT_A],	sum(volte4G.[ 14.5-15 MT_Alert]) as [30_MT_A],
		sum(volte4G.[ 15-15.5 MT_Alert]) as [31_MT_A],	sum(volte4G.[ 15.5-16 MT_Alert]) as [32_MT_A],	sum(volte4G.[ 16-16.5 MT_Alert]) as [33_MT_A],
		sum(volte4G.[ 16.5-17 MT_Alert]) as [34_MT_A],	sum(volte4G.[ 17-17.5 MT_Alert]) as [35_MT_A],	sum(volte4G.[ 17.5-18 MT_Alert]) as [36_MT_A],
		sum(volte4G.[ 18-18.5 MT_Alert]) as [37_MT_A],	sum(volte4G.[ 18.5-19 MT_Alert]) as [38_MT_A],	sum(volte4G.[ 19-19.5 MT_Alert]) as [39_MT_A],
		sum(volte4G.[ 19.5-20 MT_Alert]) as [40_MT_A],	sum(volte4G.[ >20 MT_Alert]) as [41_MT_A],

		---------------------------------
		-- Rangos MOMT ALERTING:
		sum(volte4G.[ 0-0.5 MOMT_Alert]) as [1_MOMT_A],	sum(volte4G.[ 0.5-1 MOMT_Alert]) as [2_MOMT_A],	sum(volte4G.[ 1-1.5 MOMT_Alert]) as [3_MOMT_A],
		sum(volte4G.[ 1.5-2 MOMT_Alert]) as [4_MOMT_A],	sum(volte4G.[ 2-2.5 MOMT_Alert]) as [5_MOMT_A],	sum(volte4G.[ 2.5-3 MOMT_Alert]) as [6_MOMT_A],
		sum(volte4G.[ 3-3.5 MOMT_Alert]) as [7_MOMT_A],	sum(volte4G.[ 3.5-4 MOMT_Alert]) as [8_MOMT_A],	sum(volte4G.[ 4-4.5 MOMT_Alert]) as [9_MOMT_A],
		sum(volte4G.[ 4.5-5 MOMT_Alert]) as [10_MOMT_A],	sum(volte4G.[ 5-5.5 MOMT_Alert]) as [11_MOMT_A],	sum(volte4G.[ 5.5-6 MOMT_Alert]) as [12_MOMT_A],
		sum(volte4G.[ 6-6.5 MOMT_Alert]) as [13_MOMT_A],	sum(volte4G.[ 6.5-7 MOMT_Alert]) as [14_MOMT_A],	sum(volte4G.[ 7-7.5 MOMT_Alert]) as [15_MOMT_A],
		sum(volte4G.[ 7.5-8 MOMT_Alert]) as [16_MOMT_A],	sum(volte4G.[ 8-8.5 MOMT_Alert]) as [17_MOMT_A],	sum(volte4G.[ 8.5-9 MOMT_Alert]) as [18_MOMT_A],
		sum(volte4G.[ 9-9.5 MOMT_Alert]) as [19_MOMT_A],	sum(volte4G.[ 9.5-10 MOMT_Alert]) as [20_MOMT_A],	sum(volte4G.[ 10-10.5 MOMT_Alert]) as [21_MOMT_A],
		sum(volte4G.[ 10.5-11 MOMT_Alert]) as [22_MOMT_A],	sum(volte4G.[ 11-11.5 MOMT_Alert]) as [23_MOMT_A],	sum(volte4G.[ 11.5-12 MOMT_Alert]) as [24_MOMT_A],
		sum(volte4G.[ 12-12.5 MOMT_Alert]) as [25_MOMT_A],	sum(volte4G.[ 12.5-13 MOMT_Alert]) as [26_MOMT_A],	sum(volte4G.[ 13-13.5 MOMT_Alert]) as [27_MOMT_A],
		sum(volte4G.[ 13.5-14 MOMT_Alert]) as [28_MOMT_A],	sum(volte4G.[ 14-14.5 MOMT_Alert]) as [29_MOMT_A],	sum(volte4G.[ 14.5-15 MOMT_Alert]) as [30_MOMT_A],
		sum(volte4G.[ 15-15.5 MOMT_Alert]) as [31_MOMT_A],	sum(volte4G.[ 15.5-16 MOMT_Alert]) as [32_MOMT_A],	sum(volte4G.[ 16-16.5 MOMT_Alert]) as [33_MOMT_A],
		sum(volte4G.[ 16.5-17 MOMT_Alert]) as [34_MOMT_A],	sum(volte4G.[ 17-17.5 MOMT_Alert]) as [35_MOMT_A],	sum(volte4G.[ 17.5-18 MOMT_Alert]) as [36_MOMT_A],
		sum(volte4G.[ 18-18.5 MOMT_Alert]) as [37_MOMT_A],	sum(volte4G.[ 18.5-19 MOMT_Alert]) as [38_MOMT_A],	sum(volte4G.[ 19-19.5 MOMT_Alert]) as [39_MOMT_A],
		sum(volte4G.[ 19.5-20 MOMT_Alert]) as [40_MOMT_A],	sum(volte4G.[ >20 MOMT_Alert]) as [41_MOMT_A],

		---------------------------------
		-- Rangos MO CONNECT:
		sum(volte4G.[ 0-0.5 MO_Conn]) as [1_MO_C],	sum(volte4G.[ 0.5-1 MO_Conn]) as [2_MO_C],	sum(volte4G.[ 1-1.5 MO_Conn]) as [3_MO_C],
		sum(volte4G.[ 1.5-2 MO_Conn]) as [4_MO_C],	sum(volte4G.[ 2-2.5 MO_Conn]) as [5_MO_C],	sum(volte4G.[ 2.5-3 MO_Conn]) as [6_MO_C],	
		sum(volte4G.[ 3-3.5 MO_Conn]) as [7_MO_C],	sum(volte4G.[ 3.5-4 MO_Conn]) as [8_MO_C],	sum(volte4G.[ 4-4.5 MO_Conn]) as [9_MO_C],
		sum(volte4G.[ 4.5-5 MO_Conn]) as [10_MO_C],	sum(volte4G.[ 5-5.5 MO_Conn]) as [11_MO_C],	sum(volte4G.[ 5.5-6 MO_Conn]) as [12_MO_C],
		sum(volte4G.[ 6-6.5 MO_Conn]) as [13_MO_C],	sum(volte4G.[ 6.5-7 MO_Conn]) as [14_MO_C],	sum(volte4G.[ 7-7.5 MO_Conn]) as [15_MO_C],
		sum(volte4G.[ 7.5-8 MO_Conn]) as [16_MO_C],	sum(volte4G.[ 8-8.5 MO_Conn]) as [17_MO_C],	sum(volte4G.[ 8.5-9 MO_Conn]) as [18_MO_C],
		sum(volte4G.[ 9-9.5 MO_Conn]) as [19_MO_C],	sum(volte4G.[ 9.5-10 MO_Conn]) as [20_MO_C],	sum(volte4G.[ 10-10.5 MO_Conn]) as [21_MO_C],
		sum(volte4G.[ 10.5-11 MO_Conn]) as [22_MO_C],	sum(volte4G.[ 11-11.5 MO_Conn]) as [23_MO_C],	sum(volte4G.[ 11.5-12 MO_Conn]) as [24_MO_C],
		sum(volte4G.[ 12-12.5 MO_Conn]) as [25_MO_C],	sum(volte4G.[ 12.5-13 MO_Conn]) as [26_MO_C],	sum(volte4G.[ 13-13.5 MO_Conn]) as [27_MO_C],
		sum(volte4G.[ 13.5-14 MO_Conn]) as [28_MO_C],	sum(volte4G.[ 14-14.5 MO_Conn]) as [29_MO_C],	sum(volte4G.[ 14.5-15 MO_Conn]) as [30_MO_C],
		sum(volte4G.[ 15-15.5 MO_Conn]) as [31_MO_C],	sum(volte4G.[ 15.5-16 MO_Conn]) as [32_MO_C],	sum(volte4G.[ 16-16.5 MO_Conn]) as [33_MO_C],
		sum(volte4G.[ 16.5-17 MO_Conn]) as [34_MO_C],	sum(volte4G.[ 17-17.5 MO_Conn]) as [35_MO_C],	sum(volte4G.[ 17.5-18 MO_Conn]) as [36_MO_C],
		sum(volte4G.[ 18-18.5 MO_Conn]) as [37_MO_C],	sum(volte4G.[ 18.5-19 MO_Conn]) as [38_MO_C],	sum(volte4G.[ 19-19.5 MO_Conn]) as [39_MO_C],
		sum(volte4G.[ 19.5-20 MO_Conn]) as [40_MO_C],	sum(volte4G.[ >20 MO_Conn]) as [41_MO_C],

		---------------------------------
		-- Rangos MT CONNECT:
		sum(volte4G.[ 0-0.5 MT_Conn]) as [1_MT_C],	sum(volte4G.[ 0.5-1 MT_Conn]) as [2_MT_C],	sum(volte4G.[ 1-1.5 MT_Conn]) as [3_MT_C],
		sum(volte4G.[ 1.5-2 MT_Conn]) as [4_MT_C],	sum(volte4G.[ 2-2.5 MT_Conn]) as [5_MT_C],	sum(volte4G.[ 2.5-3 MT_Conn]) as [6_MT_C],
		sum(volte4G.[ 3-3.5 MT_Conn]) as [7_MT_C],	sum(volte4G.[ 3.5-4 MT_Conn]) as [8_MT_C],	sum(volte4G.[ 4-4.5 MT_Conn]) as [9_MT_C],
		sum(volte4G.[ 4.5-5 MT_Conn]) as [10_MT_C],	sum(volte4G.[ 5-5.5 MT_Conn]) as [11_MT_C],	sum(volte4G.[ 5.5-6 MT_Conn]) as [12_MT_C],
		sum(volte4G.[ 6-6.5 MT_Conn]) as [13_MT_C],	sum(volte4G.[ 6.5-7 MT_Conn]) as [14_MT_C],	sum(volte4G.[ 7-7.5 MT_Conn]) as [15_MT_C],
		sum(volte4G.[ 7.5-8 MT_Conn]) as [16_MT_C],	sum(volte4G.[ 8-8.5 MT_Conn]) as [17_MT_C],	sum(volte4G.[ 8.5-9 MT_Conn]) as [18_MT_C],
		sum(volte4G.[ 9-9.5 MT_Conn]) as [19_MT_C],	sum(volte4G.[ 9.5-10 MT_Conn]) as [20_MT_C],	sum(volte4G.[ 10-10.5 MT_Conn]) as [21_MT_C],
		sum(volte4G.[ 10.5-11 MT_Conn]) as [22_MT_C],	sum(volte4G.[ 11-11.5 MT_Conn]) as [23_MT_C],	sum(volte4G.[ 11.5-12 MT_Conn]) as [24_MT_C],
		sum(volte4G.[ 12-12.5 MT_Conn]) as [25_MT_C],	sum(volte4G.[ 12.5-13 MT_Conn]) as [26_MT_C],	sum(volte4G.[ 13-13.5 MT_Conn]) as [27_MT_C],
		sum(volte4G.[ 13.5-14 MT_Conn]) as [28_MT_C],	sum(volte4G.[ 14-14.5 MT_Conn]) as [29_MT_C],	sum(volte4G.[ 14.5-15 MT_Conn]) as [30_MT_C],
		sum(volte4G.[ 15-15.5 MT_Conn]) as [31_MT_C],	sum(volte4G.[ 15.5-16 MT_Conn]) as [32_MT_C],	sum(volte4G.[ 16-16.5 MT_Conn]) as [33_MT_C],
		sum(volte4G.[ 16.5-17 MT_Conn]) as [34_MT_C],	sum(volte4G.[ 17-17.5 MT_Conn]) as [35_MT_C],	sum(volte4G.[ 17.5-18 MT_Conn]) as [36_MT_C],
		sum(volte4G.[ 18-18.5 MT_Conn]) as [37_MT_C],	sum(volte4G.[ 18.5-19 MT_Conn]) as [38_MT_C],	sum(volte4G.[ 19-19.5 MT_Conn]) as [39_MT_C],
		sum(volte4G.[ 19.5-20 MT_Conn]) as [40_MT_C],	sum(volte4G.[ >20 MT_Conn]) as [41_MT_C],

		---------------------------------
		-- Rangos MOMT CONNECT:
		sum(volte4G.[ 0-0.5 MOMT_Conn]) as [1_MOMT_C],	sum(volte4G.[ 0.5-1 MOMT_Conn]) as [2_MOMT_C],	sum(volte4G.[ 1-1.5 MOMT_Conn]) as [3_MOMT_C],
		sum(volte4G.[ 1.5-2 MOMT_Conn]) as [4_MOMT_C],	sum(volte4G.[ 2-2.5 MOMT_Conn]) as [5_MOMT_C],	sum(volte4G.[ 2.5-3 MOMT_Conn]) as [6_MOMT_C],
		sum(volte4G.[ 3-3.5 MOMT_Conn]) as [7_MOMT_C],	sum(volte4G.[ 3.5-4 MOMT_Conn]) as [8_MOMT_C],	sum(volte4G.[ 4-4.5 MOMT_Conn]) as [9_MOMT_C],
		sum(volte4G.[ 4.5-5 MOMT_Conn]) as [10_MOMT_C],	sum(volte4G.[ 5-5.5 MOMT_Conn]) as [11_MOMT_C],	sum(volte4G.[ 5.5-6 MOMT_Conn]) as [12_MOMT_C],
		sum(volte4G.[ 6-6.5 MOMT_Conn]) as [13_MOMT_C],	sum(volte4G.[ 6.5-7 MOMT_Conn]) as [14_MOMT_C],	sum(volte4G.[ 7-7.5 MOMT_Conn]) as [15_MOMT_C],
		sum(volte4G.[ 7.5-8 MOMT_Conn]) as [16_MOMT_C],	sum(volte4G.[ 8-8.5 MOMT_Conn]) as [17_MOMT_C],	sum(volte4G.[ 8.5-9 MOMT_Conn]) as [18_MOMT_C],
		sum(volte4G.[ 9-9.5 MOMT_Conn]) as [19_MOMT_C],	sum(volte4G.[ 9.5-10 MOMT_Conn]) as [20_MOMT_C],	sum(volte4G.[ 10-10.5 MOMT_Conn]) as [21_MOMT_C],
		sum(volte4G.[ 10.5-11 MOMT_Conn]) as [22_MOMT_C],	sum(volte4G.[ 11-11.5 MOMT_Conn]) as [23_MOMT_C],	sum(volte4G.[ 11.5-12 MOMT_Conn]) as [24_MOMT_C],
		sum(volte4G.[ 12-12.5 MOMT_Conn]) as [25_MOMT_C],	sum(volte4G.[ 12.5-13 MOMT_Conn]) as [26_MOMT_C],	sum(volte4G.[ 13-13.5 MOMT_Conn]) as [27_MOMT_C],
		sum(volte4G.[ 13.5-14 MOMT_Conn]) as [28_MOMT_C],	sum(volte4G.[ 14-14.5 MOMT_Conn]) as [29_MOMT_C],	sum(volte4G.[ 14.5-15 MOMT_Conn]) as [30_MOMT_C],
		sum(volte4G.[ 15-15.5 MOMT_Conn]) as [31_MOMT_C],	sum(volte4G.[ 15.5-16 MOMT_Conn]) as [32_MOMT_C],	sum(volte4G.[ 16-16.5 MOMT_Conn]) as [33_MOMT_C],
		sum(volte4G.[ 16.5-17 MOMT_Conn]) as [34_MOMT_C],	sum(volte4G.[ 17-17.5 MOMT_Conn]) as [35_MOMT_C],	sum(volte4G.[ 17.5-18 MOMT_Conn]) as [36_MOMT_C],
		sum(volte4G.[ 18-18.5 MOMT_Conn]) as [37_MOMT_C],	sum(volte4G.[ 18.5-19 MOMT_Conn]) as [38_MOMT_C],	sum(volte4G.[ 19-19.5 MOMT_Conn]) as [39_MOMT_C],
		sum(volte4G.[ 19.5-20 MOMT_Conn]) as [40_MOMT_C],	sum(volte4G.[ >20 MOMT_Conn]) as [41_MOMT_C],

		---------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP, 
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]	

	from [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls] volte
				LEFT OUTER JOIN [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls_4G] volte4G on  (isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')=isnull(volte4G.parcel,'0.00000 Long, 0.00000 Lat') and volte.mnc=volte4G.mnc and volte.Date_Reporting=volte4G.Date_Reporting and volte.entidad=volte4G.entidad and volte.Aggr_Type=volte4G.Aggr_Type and volte.Report_Type=volte4G.Report_Type and volte.meas_round=volte4G.meas_round) 
		, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end, case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 4G Road' 
			else 'VOLTE 4G' end, volte.mnc,volte.meas_round,volte.Date_Reporting,volte.Week_Reporting,volte.entidad,volte.Report_Type,volte.aggr_type, 
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	---------
	-- VOLTE RealVolte:
	insert into _RI_Voice_cst
	select 
		volte.calltype as Calltype,
		p.codigo_ine,  
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment,volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE RealVOLTE Road' 
			else 'VOLTE RealVOLTE' end as meas_Tech, 1 as info_available,volte.entidad as vf_entity,volte.Report_Type,volte.aggr_type,
    
		0.001*(1000.0*SUM(volteRV.[CST_MOMT_Alerting]*(volteRV.[Calls_AVG_ALERT_MO]+volteRV.[Calls_AVG_ALERT_MT]))) as CST_ALERTING_NUM,
		0.001*(1000.0*SUM(volteRV.[CST_MOMT_Connect]*(volteRV.[Calls_AVG_CONNECT_MO]+volteRV.[Calls_AVG_CONNECT_MT]))) as CST_CONNECT_NUM,

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(volteRV.[Calls_AVG_ALERT_MO]) as CST_MO_AL_samples,
		sum(volteRV.[Calls_AVG_ALERT_MT]) as CST_MT_AL_samples,
		sum(volteRV.[Calls_AVG_CONNECT_MO]) as CST_MO_CO_Samples,
		sum(volteRV.[Calls_AVG_CONNECT_MT]) as CST_MT_CO_Samples,

		0.001*(1000.0*SUM(volteRV.[CST_MO_Alerting]*volteRV.[Calls_AVG_ALERT_MO])) as CST_MO_AL_NUM,
		0.001*(1000.0*SUM(volteRV.[CST_MT_Alerting]*volteRV.[Calls_AVG_ALERT_MT])) as CST_MT_AL_NUM,
		0.001*(1000.0*SUM(volteRV.[CST_MO_Connect]*volteRV.[Calls_AVG_CONNECT_MO])) as CST_MO_CO_NUM,
		0.001*(1000.0*SUM(volteRV.[CST_MT_Connect]*volteRV.[Calls_AVG_CONNECT_MT])) as CST_MT_CO_NUM,

		---------------------------------
		-- Rangos MO ALERTING:
		sum(volteRV.[ 0-0.5 MO_Alert]) as [1_MO_A],	sum(volteRV.[ 0.5-1 MO_Alert]) as [2_MO_A],		sum(volteRV.[ 1-1.5 MO_Alert]) as [3_MO_A],
		sum(volteRV.[ 1.5-2 MO_Alert]) as [4_MO_A],	sum(volteRV.[ 2-2.5 MO_Alert]) as [5_MO_A],		sum(volteRV.[ 2.5-3 MO_Alert]) as [6_MO_A],
		sum(volteRV.[ 3-3.5 MO_Alert]) as [7_MO_A],	sum(volteRV.[ 3.5-4 MO_Alert]) as [8_MO_A],		sum(volteRV.[ 4-4.5 MO_Alert]) as [9_MO_A],
		sum(volteRV.[ 4.5-5 MO_Alert]) as [10_MO_A],	sum(volteRV.[ 5-5.5 MO_Alert]) as [11_MO_A],		sum(volteRV.[ 5.5-6 MO_Alert]) as [12_MO_A],
		sum(volteRV.[ 6-6.5 MO_Alert]) as [13_MO_A],	sum(volteRV.[ 6.5-7 MO_Alert]) as [14_MO_A],		sum(volteRV.[ 7-7.5 MO_Alert]) as [15_MO_A],
		sum(volteRV.[ 7.5-8 MO_Alert]) as [16_MO_A],	sum(volteRV.[ 8-8.5 MO_Alert]) as [17_MO_A],		sum(volteRV.[ 8.5-9 MO_Alert]) as [18_MO_A],
		sum(volteRV.[ 9-9.5 MO_Alert]) as [19_MO_A],	sum(volteRV.[ 9.5-10 MO_Alert]) as [20_MO_A],		sum(volteRV.[ 10-10.5 MO_Alert]) as [21_MO_A],
		sum(volteRV.[ 10.5-11 MO_Alert]) as [22_MO_A],	sum(volteRV.[ 11-11.5 MO_Alert]) as [23_MO_A],	sum(volteRV.[ 11.5-12 MO_Alert]) as [24_MO_A],
		sum(volteRV.[ 12-12.5 MO_Alert]) as [25_MO_A],	sum(volteRV.[ 12.5-13 MO_Alert]) as [26_MO_A],	sum(volteRV.[ 13-13.5 MO_Alert]) as [27_MO_A],
		sum(volteRV.[ 13.5-14 MO_Alert]) as [28_MO_A],	sum(volteRV.[ 14-14.5 MO_Alert]) as [29_MO_A],	sum(volteRV.[ 14.5-15 MO_Alert]) as [30_MO_A],
		sum(volteRV.[ 15-15.5 MO_Alert]) as [31_MO_A],	sum(volteRV.[ 15.5-16 MO_Alert]) as [32_MO_A],	sum(volteRV.[ 16-16.5 MO_Alert]) as [33_MO_A],
		sum(volteRV.[ 16.5-17 MO_Alert]) as [34_MO_A],	sum(volteRV.[ 17-17.5 MO_Alert]) as [35_MO_A],	sum(volteRV.[ 17.5-18 MO_Alert]) as [36_MO_A],
		sum(volteRV.[ 18-18.5 MO_Alert]) as [37_MO_A],	sum(volteRV.[ 18.5-19 MO_Alert]) as [38_MO_A],	sum(volteRV.[ 19-19.5 MO_Alert]) as [39_MO_A],
		sum(volteRV.[ 19.5-20 MO_Alert]) as [40_MO_A],	sum(volteRV.[ >20 MO_Alert]) as [41_MO_A],
		
		---------------------------------
		-- Rangos MT ALERTING:
		sum(volteRV.[ 0-0.5 MT_Alert]) as [1_MT_A],	sum(volteRV.[ 0.5-1 MT_Alert]) as [2_MT_A],		sum(volteRV.[ 1-1.5 MT_Alert]) as [3_MT_A],
		sum(volteRV.[ 1.5-2 MT_Alert]) as [4_MT_A],	sum(volteRV.[ 2-2.5 MT_Alert]) as [5_MT_A],		sum(volteRV.[ 2.5-3 MT_Alert]) as [6_MT_A],
		sum(volteRV.[ 3-3.5 MT_Alert]) as [7_MT_A],	sum(volteRV.[ 3.5-4 MT_Alert]) as [8_MT_A],		sum(volteRV.[ 4-4.5 MT_Alert]) as [9_MT_A],
		sum(volteRV.[ 4.5-5 MT_Alert]) as [10_MT_A],	sum(volteRV.[ 5-5.5 MT_Alert]) as [11_MT_A],		sum(volteRV.[ 5.5-6 MT_Alert]) as [12_MT_A],
		sum(volteRV.[ 6-6.5 MT_Alert]) as [13_MT_A],	sum(volteRV.[ 6.5-7 MT_Alert]) as [14_MT_A],		sum(volteRV.[ 7-7.5 MT_Alert]) as [15_MT_A],
		sum(volteRV.[ 7.5-8 MT_Alert]) as [16_MT_A],	sum(volteRV.[ 8-8.5 MT_Alert]) as [17_MT_A],		sum(volteRV.[ 8.5-9 MT_Alert]) as [18_MT_A],
		sum(volteRV.[ 9-9.5 MT_Alert]) as [19_MT_A],	sum(volteRV.[ 9.5-10 MT_Alert]) as [20_MT_A],		sum(volteRV.[ 10-10.5 MT_Alert]) as [21_MT_A],
		sum(volteRV.[ 10.5-11 MT_Alert]) as [22_MT_A],	sum(volteRV.[ 11-11.5 MT_Alert]) as [23_MT_A],	sum(volteRV.[ 11.5-12 MT_Alert]) as [24_MT_A],
		sum(volteRV.[ 12-12.5 MT_Alert]) as [25_MT_A],	sum(volteRV.[ 12.5-13 MT_Alert]) as [26_MT_A],	sum(volteRV.[ 13-13.5 MT_Alert]) as [27_MT_A],
		sum(volteRV.[ 13.5-14 MT_Alert]) as [28_MT_A],	sum(volteRV.[ 14-14.5 MT_Alert]) as [29_MT_A],	sum(volteRV.[ 14.5-15 MT_Alert]) as [30_MT_A],
		sum(volteRV.[ 15-15.5 MT_Alert]) as [31_MT_A],	sum(volteRV.[ 15.5-16 MT_Alert]) as [32_MT_A],	sum(volteRV.[ 16-16.5 MT_Alert]) as [33_MT_A],
		sum(volteRV.[ 16.5-17 MT_Alert]) as [34_MT_A],	sum(volteRV.[ 17-17.5 MT_Alert]) as [35_MT_A],	sum(volteRV.[ 17.5-18 MT_Alert]) as [36_MT_A],
		sum(volteRV.[ 18-18.5 MT_Alert]) as [37_MT_A],	sum(volteRV.[ 18.5-19 MT_Alert]) as [38_MT_A],	sum(volteRV.[ 19-19.5 MT_Alert]) as [39_MT_A],
		sum(volteRV.[ 19.5-20 MT_Alert]) as [40_MT_A],	sum(volteRV.[ >20 MT_Alert]) as [41_MT_A],

		---------------------------------
		-- Rangos MOMT ALERTING:
		sum(volteRV.[ 0-0.5 MOMT_Alert]) as [1_MOMT_A],	sum(volteRV.[ 0.5-1 MOMT_Alert]) as [2_MOMT_A],	sum(volteRV.[ 1-1.5 MOMT_Alert]) as [3_MOMT_A],
		sum(volteRV.[ 1.5-2 MOMT_Alert]) as [4_MOMT_A],	sum(volteRV.[ 2-2.5 MOMT_Alert]) as [5_MOMT_A],	sum(volteRV.[ 2.5-3 MOMT_Alert]) as [6_MOMT_A],
		sum(volteRV.[ 3-3.5 MOMT_Alert]) as [7_MOMT_A],	sum(volteRV.[ 3.5-4 MOMT_Alert]) as [8_MOMT_A],	sum(volteRV.[ 4-4.5 MOMT_Alert]) as [9_MOMT_A],
		sum(volteRV.[ 4.5-5 MOMT_Alert]) as [10_MOMT_A],	sum(volteRV.[ 5-5.5 MOMT_Alert]) as [11_MOMT_A],	sum(volteRV.[ 5.5-6 MOMT_Alert]) as [12_MOMT_A],
		sum(volteRV.[ 6-6.5 MOMT_Alert]) as [13_MOMT_A],	sum(volteRV.[ 6.5-7 MOMT_Alert]) as [14_MOMT_A],	sum(volteRV.[ 7-7.5 MOMT_Alert]) as [15_MOMT_A],
		sum(volteRV.[ 7.5-8 MOMT_Alert]) as [16_MOMT_A],	sum(volteRV.[ 8-8.5 MOMT_Alert]) as [17_MOMT_A],	sum(volteRV.[ 8.5-9 MOMT_Alert]) as [18_MOMT_A],
		sum(volteRV.[ 9-9.5 MOMT_Alert]) as [19_MOMT_A],	sum(volteRV.[ 9.5-10 MOMT_Alert]) as [20_MOMT_A],	sum(volteRV.[ 10-10.5 MOMT_Alert]) as [21_MOMT_A],
		sum(volteRV.[ 10.5-11 MOMT_Alert]) as [22_MOMT_A],	sum(volteRV.[ 11-11.5 MOMT_Alert]) as [23_MOMT_A],	sum(volteRV.[ 11.5-12 MOMT_Alert]) as [24_MOMT_A],
		sum(volteRV.[ 12-12.5 MOMT_Alert]) as [25_MOMT_A],	sum(volteRV.[ 12.5-13 MOMT_Alert]) as [26_MOMT_A],	sum(volteRV.[ 13-13.5 MOMT_Alert]) as [27_MOMT_A],
		sum(volteRV.[ 13.5-14 MOMT_Alert]) as [28_MOMT_A],	sum(volteRV.[ 14-14.5 MOMT_Alert]) as [29_MOMT_A],	sum(volteRV.[ 14.5-15 MOMT_Alert]) as [30_MOMT_A],
		sum(volteRV.[ 15-15.5 MOMT_Alert]) as [31_MOMT_A],	sum(volteRV.[ 15.5-16 MOMT_Alert]) as [32_MOMT_A],	sum(volteRV.[ 16-16.5 MOMT_Alert]) as [33_MOMT_A],
		sum(volteRV.[ 16.5-17 MOMT_Alert]) as [34_MOMT_A],	sum(volteRV.[ 17-17.5 MOMT_Alert]) as [35_MOMT_A],	sum(volteRV.[ 17.5-18 MOMT_Alert]) as [36_MOMT_A],
		sum(volteRV.[ 18-18.5 MOMT_Alert]) as [37_MOMT_A],	sum(volteRV.[ 18.5-19 MOMT_Alert]) as [38_MOMT_A],	sum(volteRV.[ 19-19.5 MOMT_Alert]) as [39_MOMT_A],
		sum(volteRV.[ 19.5-20 MOMT_Alert]) as [40_MOMT_A],	sum(volteRV.[ >20 MOMT_Alert]) as [41_MOMT_A],

		---------------------------------
		-- Rangos MO CONNECT:
		sum(volteRV.[ 0-0.5 MO_Conn]) as [1_MO_C],	sum(volteRV.[ 0.5-1 MO_Conn]) as [2_MO_C],	sum(volteRV.[ 1-1.5 MO_Conn]) as [3_MO_C],
		sum(volteRV.[ 1.5-2 MO_Conn]) as [4_MO_C],	sum(volteRV.[ 2-2.5 MO_Conn]) as [5_MO_C],	sum(volteRV.[ 2.5-3 MO_Conn]) as [6_MO_C],	
		sum(volteRV.[ 3-3.5 MO_Conn]) as [7_MO_C],	sum(volteRV.[ 3.5-4 MO_Conn]) as [8_MO_C],	sum(volteRV.[ 4-4.5 MO_Conn]) as [9_MO_C],
		sum(volteRV.[ 4.5-5 MO_Conn]) as [10_MO_C],	sum(volteRV.[ 5-5.5 MO_Conn]) as [11_MO_C],	sum(volteRV.[ 5.5-6 MO_Conn]) as [12_MO_C],
		sum(volteRV.[ 6-6.5 MO_Conn]) as [13_MO_C],	sum(volteRV.[ 6.5-7 MO_Conn]) as [14_MO_C],	sum(volteRV.[ 7-7.5 MO_Conn]) as [15_MO_C],
		sum(volteRV.[ 7.5-8 MO_Conn]) as [16_MO_C],	sum(volteRV.[ 8-8.5 MO_Conn]) as [17_MO_C],	sum(volteRV.[ 8.5-9 MO_Conn]) as [18_MO_C],
		sum(volteRV.[ 9-9.5 MO_Conn]) as [19_MO_C],	sum(volteRV.[ 9.5-10 MO_Conn]) as [20_MO_C],	sum(volteRV.[ 10-10.5 MO_Conn]) as [21_MO_C],
		sum(volteRV.[ 10.5-11 MO_Conn]) as [22_MO_C],	sum(volteRV.[ 11-11.5 MO_Conn]) as [23_MO_C],	sum(volteRV.[ 11.5-12 MO_Conn]) as [24_MO_C],
		sum(volteRV.[ 12-12.5 MO_Conn]) as [25_MO_C],	sum(volteRV.[ 12.5-13 MO_Conn]) as [26_MO_C],	sum(volteRV.[ 13-13.5 MO_Conn]) as [27_MO_C],
		sum(volteRV.[ 13.5-14 MO_Conn]) as [28_MO_C],	sum(volteRV.[ 14-14.5 MO_Conn]) as [29_MO_C],	sum(volteRV.[ 14.5-15 MO_Conn]) as [30_MO_C],
		sum(volteRV.[ 15-15.5 MO_Conn]) as [31_MO_C],	sum(volteRV.[ 15.5-16 MO_Conn]) as [32_MO_C],	sum(volteRV.[ 16-16.5 MO_Conn]) as [33_MO_C],
		sum(volteRV.[ 16.5-17 MO_Conn]) as [34_MO_C],	sum(volteRV.[ 17-17.5 MO_Conn]) as [35_MO_C],	sum(volteRV.[ 17.5-18 MO_Conn]) as [36_MO_C],
		sum(volteRV.[ 18-18.5 MO_Conn]) as [37_MO_C],	sum(volteRV.[ 18.5-19 MO_Conn]) as [38_MO_C],	sum(volteRV.[ 19-19.5 MO_Conn]) as [39_MO_C],
		sum(volteRV.[ 19.5-20 MO_Conn]) as [40_MO_C],	sum(volteRV.[ >20 MO_Conn]) as [41_MO_C],

		---------------------------------
		-- Rangos MT CONNECT:
		sum(volteRV.[ 0-0.5 MT_Conn]) as [1_MT_C],	sum(volteRV.[ 0.5-1 MT_Conn]) as [2_MT_C],	sum(volteRV.[ 1-1.5 MT_Conn]) as [3_MT_C],
		sum(volteRV.[ 1.5-2 MT_Conn]) as [4_MT_C],	sum(volteRV.[ 2-2.5 MT_Conn]) as [5_MT_C],	sum(volteRV.[ 2.5-3 MT_Conn]) as [6_MT_C],
		sum(volteRV.[ 3-3.5 MT_Conn]) as [7_MT_C],	sum(volteRV.[ 3.5-4 MT_Conn]) as [8_MT_C],	sum(volteRV.[ 4-4.5 MT_Conn]) as [9_MT_C],
		sum(volteRV.[ 4.5-5 MT_Conn]) as [10_MT_C],	sum(volteRV.[ 5-5.5 MT_Conn]) as [11_MT_C],	sum(volteRV.[ 5.5-6 MT_Conn]) as [12_MT_C],
		sum(volteRV.[ 6-6.5 MT_Conn]) as [13_MT_C],	sum(volteRV.[ 6.5-7 MT_Conn]) as [14_MT_C],	sum(volteRV.[ 7-7.5 MT_Conn]) as [15_MT_C],
		sum(volteRV.[ 7.5-8 MT_Conn]) as [16_MT_C],	sum(volteRV.[ 8-8.5 MT_Conn]) as [17_MT_C],	sum(volteRV.[ 8.5-9 MT_Conn]) as [18_MT_C],
		sum(volteRV.[ 9-9.5 MT_Conn]) as [19_MT_C],	sum(volteRV.[ 9.5-10 MT_Conn]) as [20_MT_C],	sum(volteRV.[ 10-10.5 MT_Conn]) as [21_MT_C],
		sum(volteRV.[ 10.5-11 MT_Conn]) as [22_MT_C],	sum(volteRV.[ 11-11.5 MT_Conn]) as [23_MT_C],	sum(volteRV.[ 11.5-12 MT_Conn]) as [24_MT_C],
		sum(volteRV.[ 12-12.5 MT_Conn]) as [25_MT_C],	sum(volteRV.[ 12.5-13 MT_Conn]) as [26_MT_C],	sum(volteRV.[ 13-13.5 MT_Conn]) as [27_MT_C],
		sum(volteRV.[ 13.5-14 MT_Conn]) as [28_MT_C],	sum(volteRV.[ 14-14.5 MT_Conn]) as [29_MT_C],	sum(volteRV.[ 14.5-15 MT_Conn]) as [30_MT_C],
		sum(volteRV.[ 15-15.5 MT_Conn]) as [31_MT_C],	sum(volteRV.[ 15.5-16 MT_Conn]) as [32_MT_C],	sum(volteRV.[ 16-16.5 MT_Conn]) as [33_MT_C],
		sum(volteRV.[ 16.5-17 MT_Conn]) as [34_MT_C],	sum(volteRV.[ 17-17.5 MT_Conn]) as [35_MT_C],	sum(volteRV.[ 17.5-18 MT_Conn]) as [36_MT_C],
		sum(volteRV.[ 18-18.5 MT_Conn]) as [37_MT_C],	sum(volteRV.[ 18.5-19 MT_Conn]) as [38_MT_C],	sum(volteRV.[ 19-19.5 MT_Conn]) as [39_MT_C],
		sum(volteRV.[ 19.5-20 MT_Conn]) as [40_MT_C],	sum(volteRV.[ >20 MT_Conn]) as [41_MT_C],

		---------------------------------
		-- Rangos MOMT CONNECT:
		sum(volteRV.[ 0-0.5 MOMT_Conn]) as [1_MOMT_C],	sum(volteRV.[ 0.5-1 MOMT_Conn]) as [2_MOMT_C],	sum(volteRV.[ 1-1.5 MOMT_Conn]) as [3_MOMT_C],
		sum(volteRV.[ 1.5-2 MOMT_Conn]) as [4_MOMT_C],	sum(volteRV.[ 2-2.5 MOMT_Conn]) as [5_MOMT_C],	sum(volteRV.[ 2.5-3 MOMT_Conn]) as [6_MOMT_C],
		sum(volteRV.[ 3-3.5 MOMT_Conn]) as [7_MOMT_C],	sum(volteRV.[ 3.5-4 MOMT_Conn]) as [8_MOMT_C],	sum(volteRV.[ 4-4.5 MOMT_Conn]) as [9_MOMT_C],
		sum(volteRV.[ 4.5-5 MOMT_Conn]) as [10_MOMT_C],	sum(volteRV.[ 5-5.5 MOMT_Conn]) as [11_MOMT_C],	sum(volteRV.[ 5.5-6 MOMT_Conn]) as [12_MOMT_C],
		sum(volteRV.[ 6-6.5 MOMT_Conn]) as [13_MOMT_C],	sum(volteRV.[ 6.5-7 MOMT_Conn]) as [14_MOMT_C],	sum(volteRV.[ 7-7.5 MOMT_Conn]) as [15_MOMT_C],
		sum(volteRV.[ 7.5-8 MOMT_Conn]) as [16_MOMT_C],	sum(volteRV.[ 8-8.5 MOMT_Conn]) as [17_MOMT_C],	sum(volteRV.[ 8.5-9 MOMT_Conn]) as [18_MOMT_C],
		sum(volteRV.[ 9-9.5 MOMT_Conn]) as [19_MOMT_C],	sum(volteRV.[ 9.5-10 MOMT_Conn]) as [20_MOMT_C],	sum(volteRV.[ 10-10.5 MOMT_Conn]) as [21_MOMT_C],
		sum(volteRV.[ 10.5-11 MOMT_Conn]) as [22_MOMT_C],	sum(volteRV.[ 11-11.5 MOMT_Conn]) as [23_MOMT_C],	sum(volteRV.[ 11.5-12 MOMT_Conn]) as [24_MOMT_C],
		sum(volteRV.[ 12-12.5 MOMT_Conn]) as [25_MOMT_C],	sum(volteRV.[ 12.5-13 MOMT_Conn]) as [26_MOMT_C],	sum(volteRV.[ 13-13.5 MOMT_Conn]) as [27_MOMT_C],
		sum(volteRV.[ 13.5-14 MOMT_Conn]) as [28_MOMT_C],	sum(volteRV.[ 14-14.5 MOMT_Conn]) as [29_MOMT_C],	sum(volteRV.[ 14.5-15 MOMT_Conn]) as [30_MOMT_C],
		sum(volteRV.[ 15-15.5 MOMT_Conn]) as [31_MOMT_C],	sum(volteRV.[ 15.5-16 MOMT_Conn]) as [32_MOMT_C],	sum(volteRV.[ 16-16.5 MOMT_Conn]) as [33_MOMT_C],
		sum(volteRV.[ 16.5-17 MOMT_Conn]) as [34_MOMT_C],	sum(volteRV.[ 17-17.5 MOMT_Conn]) as [35_MOMT_C],	sum(volteRV.[ 17.5-18 MOMT_Conn]) as [36_MOMT_C],
		sum(volteRV.[ 18-18.5 MOMT_Conn]) as [37_MOMT_C],	sum(volteRV.[ 18.5-19 MOMT_Conn]) as [38_MOMT_C],	sum(volteRV.[ 19-19.5 MOMT_Conn]) as [39_MOMT_C],
		sum(volteRV.[ 19.5-20 MOMT_Conn]) as [40_MOMT_C],	sum(volteRV.[ >20 MOMT_Conn]) as [41_MOMT_C],

		---------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP, 
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]		

	from [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls] volte
				LEFT OUTER JOIN [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls_VOLTE] volteRV on  (isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')=isnull(volteRV.parcel,'0.00000 Long, 0.00000 Lat') and volte.mnc=volteRV.mnc and volte.Date_Reporting=volteRV.Date_Reporting and volte.entidad=volteRV.entidad and volte.Aggr_Type=volteRV.Aggr_Type and volte.Report_Type=volteRV.Report_Type and volte.meas_round=volteRV.meas_round) 
		, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,  
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end, case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE RealVOLTE Road' 
			else 'VOLTE RealVOLTE' end, volte.mnc,volte.meas_round,volte.Date_Reporting,volte.Week_Reporting,volte.entidad,volte.Report_Type,volte.aggr_type,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	---------
	-- VOLTE 3G:
	insert into _RI_Voice_cst
	select 
		volte.calltype as Calltype,
		p.codigo_ine,  
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment,volte3G.mnc,volte3G.meas_round,volte3G.Date_Reporting as meas_date,volte3G.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 3G Road' 
			else 'VOLTE 3G' end as meas_Tech, 1 as info_available,volte3G.entidad as vf_entity,volte3G.Report_Type,volte3G.aggr_type,
    
		0.001*(1000.0*SUM(volte3G.[CST_MOMT_Alerting]*(volte3G.[Calls_AVG_ALERT_MO]+volte3G.[Calls_AVG_ALERT_MT]))) as CST_ALERTING_NUM,
		0.001*(1000.0*SUM(volte3G.[CST_MOMT_Connect]*(volte3G.[Calls_AVG_CONNECT_MO]+volte3G.[Calls_AVG_CONNECT_MT]))) as CST_CONNECT_NUM,

		---------------------------------
		/*kpis nuevos añadidos para qlik*/
		sum(volte3G.[Calls_AVG_ALERT_MO]) as CST_MO_AL_samples,
		sum(volte3G.[Calls_AVG_ALERT_MT]) as CST_MT_AL_samples,
		sum(volte3G.[Calls_AVG_CONNECT_MO]) as CST_MO_CO_Samples,
		sum(volte3G.[Calls_AVG_CONNECT_MT]) as CST_MT_CO_Samples,

		0.001*(1000.0*SUM(volte3G.[CST_MO_Alerting]*volte3G.[Calls_AVG_ALERT_MO])) as CST_MO_AL_NUM,
		0.001*(1000.0*SUM(volte3G.[CST_MT_Alerting]*volte3G.[Calls_AVG_ALERT_MT])) as CST_MT_AL_NUM,
		0.001*(1000.0*SUM(volte3G.[CST_MO_Connect]*volte3G.[Calls_AVG_CONNECT_MO])) as CST_MO_CO_NUM,
		0.001*(1000.0*SUM(volte3G.[CST_MT_Connect]*volte3G.[Calls_AVG_CONNECT_MT])) as CST_MT_CO_NUM,

		---------------------------------
		-- Rangos MO ALERTING:
		sum(volte3G.[ 0-0.5 MO_Alert]) as [1_MO_A],	sum(volte3G.[ 0.5-1 MO_Alert]) as [2_MO_A],		sum(volte3G.[ 1-1.5 MO_Alert]) as [3_MO_A],
		sum(volte3G.[ 1.5-2 MO_Alert]) as [4_MO_A],	sum(volte3G.[ 2-2.5 MO_Alert]) as [5_MO_A],		sum(volte3G.[ 2.5-3 MO_Alert]) as [6_MO_A],
		sum(volte3G.[ 3-3.5 MO_Alert]) as [7_MO_A],	sum(volte3G.[ 3.5-4 MO_Alert]) as [8_MO_A],		sum(volte3G.[ 4-4.5 MO_Alert]) as [9_MO_A],
		sum(volte3G.[ 4.5-5 MO_Alert]) as [10_MO_A],	sum(volte3G.[ 5-5.5 MO_Alert]) as [11_MO_A],		sum(volte3G.[ 5.5-6 MO_Alert]) as [12_MO_A],
		sum(volte3G.[ 6-6.5 MO_Alert]) as [13_MO_A],	sum(volte3G.[ 6.5-7 MO_Alert]) as [14_MO_A],		sum(volte3G.[ 7-7.5 MO_Alert]) as [15_MO_A],
		sum(volte3G.[ 7.5-8 MO_Alert]) as [16_MO_A],	sum(volte3G.[ 8-8.5 MO_Alert]) as [17_MO_A],		sum(volte3G.[ 8.5-9 MO_Alert]) as [18_MO_A],
		sum(volte3G.[ 9-9.5 MO_Alert]) as [19_MO_A],	sum(volte3G.[ 9.5-10 MO_Alert]) as [20_MO_A],		sum(volte3G.[ 10-10.5 MO_Alert]) as [21_MO_A],
		sum(volte3G.[ 10.5-11 MO_Alert]) as [22_MO_A],	sum(volte3G.[ 11-11.5 MO_Alert]) as [23_MO_A],	sum(volte3G.[ 11.5-12 MO_Alert]) as [24_MO_A],
		sum(volte3G.[ 12-12.5 MO_Alert]) as [25_MO_A],	sum(volte3G.[ 12.5-13 MO_Alert]) as [26_MO_A],	sum(volte3G.[ 13-13.5 MO_Alert]) as [27_MO_A],
		sum(volte3G.[ 13.5-14 MO_Alert]) as [28_MO_A],	sum(volte3G.[ 14-14.5 MO_Alert]) as [29_MO_A],	sum(volte3G.[ 14.5-15 MO_Alert]) as [30_MO_A],
		sum(volte3G.[ 15-15.5 MO_Alert]) as [31_MO_A],	sum(volte3G.[ 15.5-16 MO_Alert]) as [32_MO_A],	sum(volte3G.[ 16-16.5 MO_Alert]) as [33_MO_A],
		sum(volte3G.[ 16.5-17 MO_Alert]) as [34_MO_A],	sum(volte3G.[ 17-17.5 MO_Alert]) as [35_MO_A],	sum(volte3G.[ 17.5-18 MO_Alert]) as [36_MO_A],
		sum(volte3G.[ 18-18.5 MO_Alert]) as [37_MO_A],	sum(volte3G.[ 18.5-19 MO_Alert]) as [38_MO_A],	sum(volte3G.[ 19-19.5 MO_Alert]) as [39_MO_A],
		sum(volte3G.[ 19.5-20 MO_Alert]) as [40_MO_A],	sum(volte3G.[ >20 MO_Alert]) as [41_MO_A],
		
		---------------------------------
		-- Rangos MT ALERTING:
		sum(volte3G.[ 0-0.5 MT_Alert]) as [1_MT_A],	sum(volte3G.[ 0.5-1 MT_Alert]) as [2_MT_A],		sum(volte3G.[ 1-1.5 MT_Alert]) as [3_MT_A],
		sum(volte3G.[ 1.5-2 MT_Alert]) as [4_MT_A],	sum(volte3G.[ 2-2.5 MT_Alert]) as [5_MT_A],		sum(volte3G.[ 2.5-3 MT_Alert]) as [6_MT_A],
		sum(volte3G.[ 3-3.5 MT_Alert]) as [7_MT_A],	sum(volte3G.[ 3.5-4 MT_Alert]) as [8_MT_A],		sum(volte3G.[ 4-4.5 MT_Alert]) as [9_MT_A],
		sum(volte3G.[ 4.5-5 MT_Alert]) as [10_MT_A],	sum(volte3G.[ 5-5.5 MT_Alert]) as [11_MT_A],		sum(volte3G.[ 5.5-6 MT_Alert]) as [12_MT_A],
		sum(volte3G.[ 6-6.5 MT_Alert]) as [13_MT_A],	sum(volte3G.[ 6.5-7 MT_Alert]) as [14_MT_A],		sum(volte3G.[ 7-7.5 MT_Alert]) as [15_MT_A],
		sum(volte3G.[ 7.5-8 MT_Alert]) as [16_MT_A],	sum(volte3G.[ 8-8.5 MT_Alert]) as [17_MT_A],		sum(volte3G.[ 8.5-9 MT_Alert]) as [18_MT_A],
		sum(volte3G.[ 9-9.5 MT_Alert]) as [19_MT_A],	sum(volte3G.[ 9.5-10 MT_Alert]) as [20_MT_A],		sum(volte3G.[ 10-10.5 MT_Alert]) as [21_MT_A],
		sum(volte3G.[ 10.5-11 MT_Alert]) as [22_MT_A],	sum(volte3G.[ 11-11.5 MT_Alert]) as [23_MT_A],	sum(volte3G.[ 11.5-12 MT_Alert]) as [24_MT_A],
		sum(volte3G.[ 12-12.5 MT_Alert]) as [25_MT_A],	sum(volte3G.[ 12.5-13 MT_Alert]) as [26_MT_A],	sum(volte3G.[ 13-13.5 MT_Alert]) as [27_MT_A],
		sum(volte3G.[ 13.5-14 MT_Alert]) as [28_MT_A],	sum(volte3G.[ 14-14.5 MT_Alert]) as [29_MT_A],	sum(volte3G.[ 14.5-15 MT_Alert]) as [30_MT_A],
		sum(volte3G.[ 15-15.5 MT_Alert]) as [31_MT_A],	sum(volte3G.[ 15.5-16 MT_Alert]) as [32_MT_A],	sum(volte3G.[ 16-16.5 MT_Alert]) as [33_MT_A],
		sum(volte3G.[ 16.5-17 MT_Alert]) as [34_MT_A],	sum(volte3G.[ 17-17.5 MT_Alert]) as [35_MT_A],	sum(volte3G.[ 17.5-18 MT_Alert]) as [36_MT_A],
		sum(volte3G.[ 18-18.5 MT_Alert]) as [37_MT_A],	sum(volte3G.[ 18.5-19 MT_Alert]) as [38_MT_A],	sum(volte3G.[ 19-19.5 MT_Alert]) as [39_MT_A],
		sum(volte3G.[ 19.5-20 MT_Alert]) as [40_MT_A],	sum(volte3G.[ >20 MT_Alert]) as [41_MT_A],

		---------------------------------
		-- Rangos MOMT ALERTING:
		sum(volte3G.[ 0-0.5 MOMT_Alert]) as [1_MOMT_A],	sum(volte3G.[ 0.5-1 MOMT_Alert]) as [2_MOMT_A],	sum(volte3G.[ 1-1.5 MOMT_Alert]) as [3_MOMT_A],
		sum(volte3G.[ 1.5-2 MOMT_Alert]) as [4_MOMT_A],	sum(volte3G.[ 2-2.5 MOMT_Alert]) as [5_MOMT_A],	sum(volte3G.[ 2.5-3 MOMT_Alert]) as [6_MOMT_A],
		sum(volte3G.[ 3-3.5 MOMT_Alert]) as [7_MOMT_A],	sum(volte3G.[ 3.5-4 MOMT_Alert]) as [8_MOMT_A],	sum(volte3G.[ 4-4.5 MOMT_Alert]) as [9_MOMT_A],
		sum(volte3G.[ 4.5-5 MOMT_Alert]) as [10_MOMT_A],	sum(volte3G.[ 5-5.5 MOMT_Alert]) as [11_MOMT_A],	sum(volte3G.[ 5.5-6 MOMT_Alert]) as [12_MOMT_A],
		sum(volte3G.[ 6-6.5 MOMT_Alert]) as [13_MOMT_A],	sum(volte3G.[ 6.5-7 MOMT_Alert]) as [14_MOMT_A],	sum(volte3G.[ 7-7.5 MOMT_Alert]) as [15_MOMT_A],
		sum(volte3G.[ 7.5-8 MOMT_Alert]) as [16_MOMT_A],	sum(volte3G.[ 8-8.5 MOMT_Alert]) as [17_MOMT_A],	sum(volte3G.[ 8.5-9 MOMT_Alert]) as [18_MOMT_A],
		sum(volte3G.[ 9-9.5 MOMT_Alert]) as [19_MOMT_A],	sum(volte3G.[ 9.5-10 MOMT_Alert]) as [20_MOMT_A],	sum(volte3G.[ 10-10.5 MOMT_Alert]) as [21_MOMT_A],
		sum(volte3G.[ 10.5-11 MOMT_Alert]) as [22_MOMT_A],	sum(volte3G.[ 11-11.5 MOMT_Alert]) as [23_MOMT_A],	sum(volte3G.[ 11.5-12 MOMT_Alert]) as [24_MOMT_A],
		sum(volte3G.[ 12-12.5 MOMT_Alert]) as [25_MOMT_A],	sum(volte3G.[ 12.5-13 MOMT_Alert]) as [26_MOMT_A],	sum(volte3G.[ 13-13.5 MOMT_Alert]) as [27_MOMT_A],
		sum(volte3G.[ 13.5-14 MOMT_Alert]) as [28_MOMT_A],	sum(volte3G.[ 14-14.5 MOMT_Alert]) as [29_MOMT_A],	sum(volte3G.[ 14.5-15 MOMT_Alert]) as [30_MOMT_A],
		sum(volte3G.[ 15-15.5 MOMT_Alert]) as [31_MOMT_A],	sum(volte3G.[ 15.5-16 MOMT_Alert]) as [32_MOMT_A],	sum(volte3G.[ 16-16.5 MOMT_Alert]) as [33_MOMT_A],
		sum(volte3G.[ 16.5-17 MOMT_Alert]) as [34_MOMT_A],	sum(volte3G.[ 17-17.5 MOMT_Alert]) as [35_MOMT_A],	sum(volte3G.[ 17.5-18 MOMT_Alert]) as [36_MOMT_A],
		sum(volte3G.[ 18-18.5 MOMT_Alert]) as [37_MOMT_A],	sum(volte3G.[ 18.5-19 MOMT_Alert]) as [38_MOMT_A],	sum(volte3G.[ 19-19.5 MOMT_Alert]) as [39_MOMT_A],
		sum(volte3G.[ 19.5-20 MOMT_Alert]) as [40_MOMT_A],	sum(volte3G.[ >20 MOMT_Alert]) as [41_MOMT_A],

		---------------------------------
		-- Rangos MO CONNECT:
		sum(volte3G.[ 0-0.5 MO_Conn]) as [1_MO_C],	sum(volte3G.[ 0.5-1 MO_Conn]) as [2_MO_C],	sum(volte3G.[ 1-1.5 MO_Conn]) as [3_MO_C],
		sum(volte3G.[ 1.5-2 MO_Conn]) as [4_MO_C],	sum(volte3G.[ 2-2.5 MO_Conn]) as [5_MO_C],	sum(volte3G.[ 2.5-3 MO_Conn]) as [6_MO_C],	
		sum(volte3G.[ 3-3.5 MO_Conn]) as [7_MO_C],	sum(volte3G.[ 3.5-4 MO_Conn]) as [8_MO_C],	sum(volte3G.[ 4-4.5 MO_Conn]) as [9_MO_C],
		sum(volte3G.[ 4.5-5 MO_Conn]) as [10_MO_C],	sum(volte3G.[ 5-5.5 MO_Conn]) as [11_MO_C],	sum(volte3G.[ 5.5-6 MO_Conn]) as [12_MO_C],
		sum(volte3G.[ 6-6.5 MO_Conn]) as [13_MO_C],	sum(volte3G.[ 6.5-7 MO_Conn]) as [14_MO_C],	sum(volte3G.[ 7-7.5 MO_Conn]) as [15_MO_C],
		sum(volte3G.[ 7.5-8 MO_Conn]) as [16_MO_C],	sum(volte3G.[ 8-8.5 MO_Conn]) as [17_MO_C],	sum(volte3G.[ 8.5-9 MO_Conn]) as [18_MO_C],
		sum(volte3G.[ 9-9.5 MO_Conn]) as [19_MO_C],	sum(volte3G.[ 9.5-10 MO_Conn]) as [20_MO_C],	sum(volte3G.[ 10-10.5 MO_Conn]) as [21_MO_C],
		sum(volte3G.[ 10.5-11 MO_Conn]) as [22_MO_C],	sum(volte3G.[ 11-11.5 MO_Conn]) as [23_MO_C],	sum(volte3G.[ 11.5-12 MO_Conn]) as [24_MO_C],
		sum(volte3G.[ 12-12.5 MO_Conn]) as [25_MO_C],	sum(volte3G.[ 12.5-13 MO_Conn]) as [26_MO_C],	sum(volte3G.[ 13-13.5 MO_Conn]) as [27_MO_C],
		sum(volte3G.[ 13.5-14 MO_Conn]) as [28_MO_C],	sum(volte3G.[ 14-14.5 MO_Conn]) as [29_MO_C],	sum(volte3G.[ 14.5-15 MO_Conn]) as [30_MO_C],
		sum(volte3G.[ 15-15.5 MO_Conn]) as [31_MO_C],	sum(volte3G.[ 15.5-16 MO_Conn]) as [32_MO_C],	sum(volte3G.[ 16-16.5 MO_Conn]) as [33_MO_C],
		sum(volte3G.[ 16.5-17 MO_Conn]) as [34_MO_C],	sum(volte3G.[ 17-17.5 MO_Conn]) as [35_MO_C],	sum(volte3G.[ 17.5-18 MO_Conn]) as [36_MO_C],
		sum(volte3G.[ 18-18.5 MO_Conn]) as [37_MO_C],	sum(volte3G.[ 18.5-19 MO_Conn]) as [38_MO_C],	sum(volte3G.[ 19-19.5 MO_Conn]) as [39_MO_C],
		sum(volte3G.[ 19.5-20 MO_Conn]) as [40_MO_C],	sum(volte3G.[ >20 MO_Conn]) as [41_MO_C],

		---------------------------------
		-- Rangos MT CONNECT:
		sum(volte3G.[ 0-0.5 MT_Conn]) as [1_MT_C],	sum(volte3G.[ 0.5-1 MT_Conn]) as [2_MT_C],	sum(volte3G.[ 1-1.5 MT_Conn]) as [3_MT_C],
		sum(volte3G.[ 1.5-2 MT_Conn]) as [4_MT_C],	sum(volte3G.[ 2-2.5 MT_Conn]) as [5_MT_C],	sum(volte3G.[ 2.5-3 MT_Conn]) as [6_MT_C],
		sum(volte3G.[ 3-3.5 MT_Conn]) as [7_MT_C],	sum(volte3G.[ 3.5-4 MT_Conn]) as [8_MT_C],	sum(volte3G.[ 4-4.5 MT_Conn]) as [9_MT_C],
		sum(volte3G.[ 4.5-5 MT_Conn]) as [10_MT_C],	sum(volte3G.[ 5-5.5 MT_Conn]) as [11_MT_C],	sum(volte3G.[ 5.5-6 MT_Conn]) as [12_MT_C],
		sum(volte3G.[ 6-6.5 MT_Conn]) as [13_MT_C],	sum(volte3G.[ 6.5-7 MT_Conn]) as [14_MT_C],	sum(volte3G.[ 7-7.5 MT_Conn]) as [15_MT_C],
		sum(volte3G.[ 7.5-8 MT_Conn]) as [16_MT_C],	sum(volte3G.[ 8-8.5 MT_Conn]) as [17_MT_C],	sum(volte3G.[ 8.5-9 MT_Conn]) as [18_MT_C],
		sum(volte3G.[ 9-9.5 MT_Conn]) as [19_MT_C],	sum(volte3G.[ 9.5-10 MT_Conn]) as [20_MT_C],	sum(volte3G.[ 10-10.5 MT_Conn]) as [21_MT_C],
		sum(volte3G.[ 10.5-11 MT_Conn]) as [22_MT_C],	sum(volte3G.[ 11-11.5 MT_Conn]) as [23_MT_C],	sum(volte3G.[ 11.5-12 MT_Conn]) as [24_MT_C],
		sum(volte3G.[ 12-12.5 MT_Conn]) as [25_MT_C],	sum(volte3G.[ 12.5-13 MT_Conn]) as [26_MT_C],	sum(volte3G.[ 13-13.5 MT_Conn]) as [27_MT_C],
		sum(volte3G.[ 13.5-14 MT_Conn]) as [28_MT_C],	sum(volte3G.[ 14-14.5 MT_Conn]) as [29_MT_C],	sum(volte3G.[ 14.5-15 MT_Conn]) as [30_MT_C],
		sum(volte3G.[ 15-15.5 MT_Conn]) as [31_MT_C],	sum(volte3G.[ 15.5-16 MT_Conn]) as [32_MT_C],	sum(volte3G.[ 16-16.5 MT_Conn]) as [33_MT_C],
		sum(volte3G.[ 16.5-17 MT_Conn]) as [34_MT_C],	sum(volte3G.[ 17-17.5 MT_Conn]) as [35_MT_C],	sum(volte3G.[ 17.5-18 MT_Conn]) as [36_MT_C],
		sum(volte3G.[ 18-18.5 MT_Conn]) as [37_MT_C],	sum(volte3G.[ 18.5-19 MT_Conn]) as [38_MT_C],	sum(volte3G.[ 19-19.5 MT_Conn]) as [39_MT_C],
		sum(volte3G.[ 19.5-20 MT_Conn]) as [40_MT_C],	sum(volte3G.[ >20 MT_Conn]) as [41_MT_C],

		---------------------------------
		-- Rangos MOMT CONNECT:
		sum(volte3G.[ 0-0.5 MOMT_Conn]) as [1_MOMT_C],	sum(volte3G.[ 0.5-1 MOMT_Conn]) as [2_MOMT_C],	sum(volte3G.[ 1-1.5 MOMT_Conn]) as [3_MOMT_C],
		sum(volte3G.[ 1.5-2 MOMT_Conn]) as [4_MOMT_C],	sum(volte3G.[ 2-2.5 MOMT_Conn]) as [5_MOMT_C],	sum(volte3G.[ 2.5-3 MOMT_Conn]) as [6_MOMT_C],
		sum(volte3G.[ 3-3.5 MOMT_Conn]) as [7_MOMT_C],	sum(volte3G.[ 3.5-4 MOMT_Conn]) as [8_MOMT_C],	sum(volte3G.[ 4-4.5 MOMT_Conn]) as [9_MOMT_C],
		sum(volte3G.[ 4.5-5 MOMT_Conn]) as [10_MOMT_C],	sum(volte3G.[ 5-5.5 MOMT_Conn]) as [11_MOMT_C],	sum(volte3G.[ 5.5-6 MOMT_Conn]) as [12_MOMT_C],
		sum(volte3G.[ 6-6.5 MOMT_Conn]) as [13_MOMT_C],	sum(volte3G.[ 6.5-7 MOMT_Conn]) as [14_MOMT_C],	sum(volte3G.[ 7-7.5 MOMT_Conn]) as [15_MOMT_C],
		sum(volte3G.[ 7.5-8 MOMT_Conn]) as [16_MOMT_C],	sum(volte3G.[ 8-8.5 MOMT_Conn]) as [17_MOMT_C],	sum(volte3G.[ 8.5-9 MOMT_Conn]) as [18_MOMT_C],
		sum(volte3G.[ 9-9.5 MOMT_Conn]) as [19_MOMT_C],	sum(volte3G.[ 9.5-10 MOMT_Conn]) as [20_MOMT_C],	sum(volte3G.[ 10-10.5 MOMT_Conn]) as [21_MOMT_C],
		sum(volte3G.[ 10.5-11 MOMT_Conn]) as [22_MOMT_C],	sum(volte3G.[ 11-11.5 MOMT_Conn]) as [23_MOMT_C],	sum(volte3G.[ 11.5-12 MOMT_Conn]) as [24_MOMT_C],
		sum(volte3G.[ 12-12.5 MOMT_Conn]) as [25_MOMT_C],	sum(volte3G.[ 12.5-13 MOMT_Conn]) as [26_MOMT_C],	sum(volte3G.[ 13-13.5 MOMT_Conn]) as [27_MOMT_C],
		sum(volte3G.[ 13.5-14 MOMT_Conn]) as [28_MOMT_C],	sum(volte3G.[ 14-14.5 MOMT_Conn]) as [29_MOMT_C],	sum(volte3G.[ 14.5-15 MOMT_Conn]) as [30_MOMT_C],
		sum(volte3G.[ 15-15.5 MOMT_Conn]) as [31_MOMT_C],	sum(volte3G.[ 15.5-16 MOMT_Conn]) as [32_MOMT_C],	sum(volte3G.[ 16-16.5 MOMT_Conn]) as [33_MOMT_C],
		sum(volte3G.[ 16.5-17 MOMT_Conn]) as [34_MOMT_C],	sum(volte3G.[ 17-17.5 MOMT_Conn]) as [35_MOMT_C],	sum(volte3G.[ 17.5-18 MOMT_Conn]) as [36_MOMT_C],
		sum(volte3G.[ 18-18.5 MOMT_Conn]) as [37_MOMT_C],	sum(volte3G.[ 18.5-19 MOMT_Conn]) as [38_MOMT_C],	sum(volte3G.[ 19-19.5 MOMT_Conn]) as [39_MOMT_C],
		sum(volte3G.[ 19.5-20 MOMT_Conn]) as [40_MOMT_C],	sum(volte3G.[ >20 MOMT_Conn]) as [41_MOMT_C],

		---------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP, 
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]	

	from [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls] volte
				LEFT OUTER JOIN [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_CallSetupTime_CompletedCalls_3G] volte3G on  (isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')=isnull(volte3G.parcel,'0.00000 Long, 0.00000 Lat') and volte.mnc=volte3G.mnc and volte.Date_Reporting=volte3G.Date_Reporting and volte.entidad=volte3G.entidad and volte.Aggr_Type=volte3G.Aggr_Type and volte.Report_Type=volte3G.Report_Type and volte.meas_round=volte3G.meas_round) 
		, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,  
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end, case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 3G Road' 
			else 'VOLTE 3G' end, volte3G.mnc,volte3G.meas_round,volte3G.Date_Reporting,volte3G.Week_Reporting,volte3G.entidad,volte3G.Report_Type,volte3G.aggr_type,
		case 
			when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		else null end,
		case 
			when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		else null end, volte.calltype,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 3.3 CST VOLTE - ALL, 4G, RealVOLTE, 3G', getdate()


	------------------------------------------------------------------------------
	-- 4. CST TECNOLOGIA y CSFB duration 3G, 4G y Road
	-- Desgloses MOS
	-- Desgloses duraciones
	-- Añadido info VOLTE (aLL, 4G, RealVOLTE, 3G)
	------------------------------------------------------------------------------ 
	print '4.1 CST TECNOLOGIA y CSFB duration 3G, 4G y Road'
	-----------	
	-- 3G:
	insert into _RI_Voice_cst_csfb
	select
		cst.calltype as Calltype,  
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week, 
	   '3G' as meas_Tech, 1 as info_available, entidad as vf_entity, Report_Type, aggr_type,
    
		-- Alerting:
		SUM(CST.Calls_CST_MOMT_ALERT_UMTS) as CST_ALERTING_UMTS_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_UMTS900) as CST_ALERTING_UMTS900_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_UMTS2100) as CST_ALERTING_UMTS2100_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_GSM) as CST_ALERTING_GSM_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_GSM900) as CST_ALERTING_GSM900_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_GSM1800) as CST_ALERTING_GSM1800_samples,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_UMTS*CST.Calls_CST_MOMT_ALERT_UMTS)) as CST_ALERTING_UMTS_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_UMTS900*CST.Calls_CST_MOMT_ALERT_UMTS900)) as CST_ALERTING_UMTS900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_UMTS2100*CST.Calls_CST_MOMT_ALERT_UMTS2100)) as CST_ALERTING_UMTS2100_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_GSM*CST.Calls_CST_MOMT_ALERT_GSM)) as CST_ALERTING_GSM_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_GSM900*CST.Calls_CST_MOMT_ALERT_GSM900)) as CST_ALERTING_GSM900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_GSM1800*CST.Calls_CST_MOMT_ALERT_GSM1800)) as CST_ALERTING_GSM1800_NUM,

		-- Connect:
		SUM(CST.Calls_CST_MOMT_CONNECT_UMTS) as CST_CONNECT_UMTS_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_UMTS900) as CST_CONNECT_UMTS900_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_UMTS2100) as CST_CONNECT_UMTS2100_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_GSM) as CST_CONNECT_GSM_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_GSM900) as CST_CONNECT_GSM900_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_GSM1800) as CST_CONNECT_GSM1800_samples,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_UMTS*CST.Calls_CST_MOMT_CONNECT_UMTS)) as CST_CONNECT_UMTS_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_UMTS900*CST.Calls_CST_MOMT_CONNECT_UMTS900)) as CST_CONNECT_UMTS900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_UMTS2100*CST.Calls_CST_MOMT_CONNECT_UMTS2100)) as CST_CONNECT_UMTS2100_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_GSM*CST.Calls_CST_MOMT_CONNECT_GSM)) as CST_CONNECT_GSM_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_GSM900*CST.Calls_CST_MOMT_CONNECT_GSM900)) as CST_CONNECT_GSM900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_GSM1800*CST.Calls_CST_MOMT_CONNECT_GSM1800)) as CST_CONNECT_GSM1800_NUM,

		sum(0) as CSFB_duration_samples,
		sum(0) as CSFB_duration_num,

		1.0*(sum(MOS_2G*Samples_2G)) as MOS_2G_Num,
		sum(Samples_2G) as MOS_2G_Samples,
		1.0*(sum(MOS_3G*Samples_3G)) as MOS_3G_Num,
		sum(Samples_3G) as MOS_3G_Samples,
		1.0*(sum(MOS_GSM900*Samples_GSM900)) as MOS_GSM_Num,
		sum(Samples_GSM900) as MOS_GSM_Samples,
		1.0*(sum(MOS_GSM1800*Samples_GSM1800)) as MOS_DCS_Num,
		sum(Samples_GSM1800) as MOS_DCS_Samples,
		1.0*(sum(MOS_UMTS900*Samples_UMTS900)) as MOS_UMTS900_Num,
		sum(Samples_UMTS900) as MOS_UMTS900_Samples,
		1.0*(sum(MOS_UMTS2100*Samples_UMTS2100)) as MOS_UMTS2100_Num,
		sum(Samples_UMTS2100) as MOS_UMTS2100_Samples,

		sum(Duration_UMTS2100) as Call_duration_UMTS2100,
		sum(Duration_UMTS900) as Call_duration_UMTS900,
		sum(Duration_GSM900) as Call_duration_GSM,
		sum(Duration_GSM1800) as Call_duration_DCS,

		null as Call_Duration_4G,
		null as Call_Duration_LTE2600,
		null as Call_Duration_LTE2100,
		null as Call_Duration_LTE1800,
		null as Call_Duration_LTE800,

		-------------------------------------
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end as Region_Road_VF,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end as Region_Road_OSP,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]	

	from [AGGRVoice3G].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs] cst, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end ,mnc,meas_round,Date_Reporting,Week_Reporting,entidad, Report_Type, aggr_type
		, cst.calltype, cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]--,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end

	---------
	-- 4G:
	insert into _RI_Voice_cst_csfb
	select 
		cst.calltype as Calltype, 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week, 
	   '4G' as meas_Tech, 1 as info_available, entidad as vf_entity, Report_Type, aggr_type,
    
		-- Alerting:
		SUM(CST.Calls_CST_MOMT_ALERT_UMTS) as CST_ALERTING_UMTS_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_UMTS900) as CST_ALERTING_UMTS900_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_UMTS2100) as CST_ALERTING_UMTS2100_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_GSM) as CST_ALERTING_GSM_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_GSM900) as CST_ALERTING_GSM900_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_GSM1800) as CST_ALERTING_GSM1800_samples,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_UMTS*CST.Calls_CST_MOMT_ALERT_UMTS)) as CST_ALERTING_UMTS_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_UMTS900*CST.Calls_CST_MOMT_ALERT_UMTS900)) as CST_ALERTING_UMTS900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_UMTS2100*CST.Calls_CST_MOMT_ALERT_UMTS2100)) as CST_ALERTING_UMTS2100_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_GSM*CST.Calls_CST_MOMT_ALERT_GSM)) as CST_ALERTING_GSM_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_GSM900*CST.Calls_CST_MOMT_ALERT_GSM900)) as CST_ALERTING_GSM900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_GSM1800*CST.Calls_CST_MOMT_ALERT_GSM1800)) as CST_ALERTING_GSM1800_NUM,

		-- Connect:
		SUM(CST.Calls_CST_MOMT_CONNECT_UMTS) as CST_CONNECT_UMTS_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_UMTS900) as CST_CONNECT_UMTS900_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_UMTS2100) as CST_CONNECT_UMTS2100_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_GSM) as CST_CONNECT_GSM_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_GSM900) as CST_CONNECT_GSM900_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_GSM1800) as CST_CONNECT_GSM1800_samples,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_UMTS*CST.Calls_CST_MOMT_CONNECT_UMTS)) as CST_CONNECT_UMTS_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_UMTS900*CST.Calls_CST_MOMT_CONNECT_UMTS900)) as CST_CONNECT_UMTS900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_UMTS2100*CST.Calls_CST_MOMT_CONNECT_UMTS2100)) as CST_CONNECT_UMTS2100_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_GSM*CST.Calls_CST_MOMT_CONNECT_GSM)) as CST_CONNECT_GSM_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_GSM900*CST.Calls_CST_MOMT_CONNECT_GSM900)) as CST_CONNECT_GSM900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_GSM1800*CST.Calls_CST_MOMT_CONNECT_GSM1800)) as CST_CONNECT_GSM1800_NUM,

		sum(Calls_CSFB_MOMT) as CSFB_duration_samples,
		0.001*(1000.0*sum(Calls_CSFB_MOMT*CSFB_MOMT)) as CSFB_duration_num,

		1.0*(sum(MOS_2G*Samples_2G)) as MOS_2G_Num,
		sum(Samples_2G) as MOS_2G_Samples,
		1.0*(sum(MOS_3G*Samples_3G)) as MOS_3G_Num,
		sum(Samples_3G) as MOS_3G_Samples,
		1.0*(sum(MOS_GSM900*Samples_GSM900)) as MOS_GSM_Num,
		sum(Samples_GSM900) as MOS_GSM_Samples,
		1.0*(sum(MOS_GSM1800*Samples_GSM1800)) as MOS_DCS_Num,
		sum(Samples_GSM1800) as MOS_DCS_Samples,
		1.0*(sum(MOS_UMTS900*Samples_UMTS900)) as MOS_UMTS900_Num,
		sum(Samples_UMTS900) as MOS_UMTS900_Samples,
		1.0*(sum(MOS_UMTS2100*Samples_UMTS2100)) as MOS_UMTS2100_Num,
		sum(Samples_UMTS2100) as MOS_UMTS2100_Samples,

		sum(Duration_UMTS2100) as Call_duration_UMTS2100,
		sum(Duration_UMTS900) as Call_duration_UMTS900,
		sum(Duration_GSM900) as Call_duration_GSM,
		sum(Duration_GSM1800) as Call_duration_DCS,

		sum([Duration_4G]) as Call_Duration_4G,
		sum([Duration_LTE2600]) as Call_Duration_LTE2600,
		sum([Duration_LTE2100]) as Call_Duration_LTE2100,
		sum([Duration_LTE1800]) as Call_Duration_LTE1800,
		sum([Duration_LTE800]) as Call_Duration_LTE800,

		-------------------------------------
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end as Region_Road_VF,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end as Region_Road_OSP,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]	

	from [AGGRVoice4G].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs] cst, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,mnc,meas_round,Date_Reporting,Week_Reporting,entidad, Report_Type, aggr_type
		, cst.calltype, cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]--,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end	

	---------
	-- ROAD 4G:
	insert into _RI_Voice_cst_csfb
	select 
		cst.calltype as Calltype, 
		p.codigo_ine, 'Roads' vf_environment,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week, 
		'Road 4G' as meas_Tech, 1 as info_available, entidad as vf_entity, Report_Type, aggr_type,

		-- Alerting:
		SUM(CST.Calls_CST_MOMT_ALERT_UMTS) as CST_ALERTING_UMTS_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_UMTS900) as CST_ALERTING_UMTS900_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_UMTS2100) as CST_ALERTING_UMTS2100_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_GSM) as CST_ALERTING_GSM_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_GSM900) as CST_ALERTING_GSM900_samples,
		SUM(CST.Calls_CST_MOMT_ALERT_GSM1800) as CST_ALERTING_GSM1800_samples,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_UMTS*CST.Calls_CST_MOMT_ALERT_UMTS)) as CST_ALERTING_UMTS_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_UMTS900*CST.Calls_CST_MOMT_ALERT_UMTS900)) as CST_ALERTING_UMTS900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_UMTS2100*CST.Calls_CST_MOMT_ALERT_UMTS2100)) as CST_ALERTING_UMTS2100_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_GSM*CST.Calls_CST_MOMT_ALERT_GSM)) as CST_ALERTING_GSM_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_GSM900*CST.Calls_CST_MOMT_ALERT_GSM900)) as CST_ALERTING_GSM900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_ALERT_GSM1800*CST.Calls_CST_MOMT_ALERT_GSM1800)) as CST_ALERTING_GSM1800_NUM,

		-- Connect:
		SUM(CST.Calls_CST_MOMT_CONNECT_UMTS) as CST_CONNECT_UMTS_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_UMTS900) as CST_CONNECT_UMTS900_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_UMTS2100) as CST_CONNECT_UMTS2100_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_GSM) as CST_CONNECT_GSM_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_GSM900) as CST_CONNECT_GSM900_samples,
		SUM(CST.Calls_CST_MOMT_CONNECT_GSM1800) as CST_CONNECT_GSM1800_samples,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_UMTS*CST.Calls_CST_MOMT_CONNECT_UMTS)) as CST_CONNECT_UMTS_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_UMTS900*CST.Calls_CST_MOMT_CONNECT_UMTS900)) as CST_CONNECT_UMTS900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_UMTS2100*CST.Calls_CST_MOMT_CONNECT_UMTS2100)) as CST_CONNECT_UMTS2100_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_GSM*CST.Calls_CST_MOMT_CONNECT_GSM)) as CST_CONNECT_GSM_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_GSM900*CST.Calls_CST_MOMT_CONNECT_GSM900)) as CST_CONNECT_GSM900_NUM,
		0.001*(1000.0*SUM(CST.CST_MOMT_CONNECT_GSM1800*CST.Calls_CST_MOMT_CONNECT_GSM1800)) as CST_CONNECT_GSM1800_NUM,

		sum(Calls_CSFB_MOMT) as CSFB_duration_samples,
		0.001*(1000.0*sum(Calls_CSFB_MOMT*CSFB_MOMT)) as CSFB_duration_num,

		1.0*(sum(MOS_2G*Samples_2G)) as MOS_2G_Num,
		sum(Samples_2G) as MOS_2G_Samples,
		1.0*(sum(MOS_3G*Samples_3G)) as MOS_3G_Num,
		sum(Samples_3G) as MOS_3G_Samples,
		1.0*(sum(MOS_GSM900*Samples_GSM900)) as MOS_GSM_Num,
		sum(Samples_GSM900) as MOS_GSM_Samples,
		1.0*(sum(MOS_GSM1800*Samples_GSM1800)) as MOS_DCS_Num,
		sum(Samples_GSM1800) as MOS_DCS_Samples,
		1.0*(sum(MOS_UMTS900*Samples_UMTS900)) as MOS_UMTS900_Num,
		sum(Samples_UMTS900) as MOS_UMTS900_Samples,
		1.0*(sum(MOS_UMTS2100*Samples_UMTS2100)) as MOS_UMTS2100_Num,
		sum(Samples_UMTS2100) as MOS_UMTS2100_Samples,

		sum(Duration_UMTS2100) as Call_duration_UMTS2100,
		sum(Duration_UMTS900) as Call_duration_UMTS900,
		sum(Duration_GSM900) as Call_duration_GSM,
		sum(Duration_GSM1800) as Call_duration_DCS,

		sum([Duration_4G]) asCall_Duration_4G,
		sum([Duration_LTE2600]) as Call_Duration_LTE2600,
		sum([Duration_LTE2100]) as Call_Duration_LTE2100,
		sum([Duration_LTE1800]) as Call_Duration_LTE1800,
		sum([Duration_LTE800]) as Call_Duration_LTE800,

		-------------------------------------
		--cst.Region_VF as Region_Road_VF, cst.Region_OSP as Region_Road_OSP,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]	

	from [AGGRVoice4G_Road].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs] cst, [AGRIDS].[dbo].vlcc_parcelas_osp p
		where p.parcela=isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,mnc,meas_round,Date_Reporting,Week_Reporting,entidad, Report_Type, aggr_type, cst.calltype,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]--, cst.Region_VF, cst.Region_OSP	

	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 4.1 CST TECNOLOGIA y CSFB duration 3G, 4G y Road', getdate()


	----------------------------------------------------------------------------------------------------------
	/*		4.2	Cruzamos con la tabla de 4G para saber qué entidades tenemos que reportar para 4GOnly. 
				Si una medida no ha cursado nada en esta tecnología saldría vacía.							*/
	---------------------------------------------------------------------------------------------------------- 
	print '4.2 CST TECNOLOGIA y CSFB duration 4GOnly y 4GOnly_Road'
	-----------	
	-- 4GOnly:
	insert into _RI_Voice_cst_csfb
	select 
		cst.calltype as Calltype, 
		p.codigo_ine, case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment,cst.mnc,cst.meas_round,cst.Date_Reporting as meas_date,cst.Week_Reporting as meas_week, 
	   '4GOnly' as meas_Tech, 1 as info_available,cst.entidad as vf_entity,cst.Report_Type,cst.aggr_type,

		SUM(NC4G.Calls_CST_MOMT_ALERT_UMTS) as CST_ALERTING_UMTS_samples,
		SUM(NC4G.Calls_CST_MOMT_ALERT_UMTS900) as CST_ALERTING_UMTS900_samples,
		SUM(NC4G.Calls_CST_MOMT_ALERT_UMTS2100) as CST_ALERTING_UMTS2100_samples,
		SUM(NC4G.Calls_CST_MOMT_ALERT_GSM) as CST_ALERTING_GSM_samples,
		SUM(NC4G.Calls_CST_MOMT_ALERT_GSM900) as CST_ALERTING_GSM900_samples,
		SUM(NC4G.Calls_CST_MOMT_ALERT_GSM1800) as CST_ALERTING_GSM1800_samples,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_UMTS*NC4G.Calls_CST_MOMT_ALERT_UMTS)) as CST_ALERTING_UMTS_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_UMTS900*NC4G.Calls_CST_MOMT_ALERT_UMTS900)) as CST_ALERTING_UMTS900_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_UMTS2100*NC4G.Calls_CST_MOMT_ALERT_UMTS2100)) as CST_ALERTING_UMTS2100_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_GSM*NC4G.Calls_CST_MOMT_ALERT_GSM)) as CST_ALERTING_GSM_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_GSM900*NC4G.Calls_CST_MOMT_ALERT_GSM900)) as CST_ALERTING_GSM900_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_GSM1800*NC4G.Calls_CST_MOMT_ALERT_GSM1800)) as CST_ALERTING_GSM1800_NUM,

		SUM(NC4G.Calls_CST_MOMT_CONNECT_UMTS) as CST_CONNECT_UMTS_samples,
		SUM(NC4G.Calls_CST_MOMT_CONNECT_UMTS900) as CST_CONNECT_UMTS900_samples,
		SUM(NC4G.Calls_CST_MOMT_CONNECT_UMTS2100) as CST_CONNECT_UMTS2100_samples,
		SUM(NC4G.Calls_CST_MOMT_CONNECT_GSM) as CST_CONNECT_GSM_samples,
		SUM(NC4G.Calls_CST_MOMT_CONNECT_GSM900) as CST_CONNECT_GSM900_samples,
		SUM(NC4G.Calls_CST_MOMT_CONNECT_GSM1800) as CST_CONNECT_GSM1800_samples,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_UMTS*NC4G.Calls_CST_MOMT_CONNECT_UMTS)) as CST_CONNECT_UMTS_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_UMTS900*NC4G.Calls_CST_MOMT_CONNECT_UMTS900)) as CST_CONNECT_UMTS900_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_UMTS2100*NC4G.Calls_CST_MOMT_CONNECT_UMTS2100)) as CST_CONNECT_UMTS2100_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_GSM*NC4G.Calls_CST_MOMT_CONNECT_GSM)) as CST_CONNECT_GSM_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_GSM900*NC4G.Calls_CST_MOMT_CONNECT_GSM900)) as CST_CONNECT_GSM900_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_GSM1800*NC4G.Calls_CST_MOMT_CONNECT_GSM1800)) as CST_CONNECT_GSM1800_NUM,

		sum(NC4G.Calls_CSFB_MOMT) as CSFB_duration_samples,
		0.001*(1000.0*sum(NC4G.Calls_CSFB_MOMT*NC4G.CSFB_MOMT)) as CSFB_duration_num,

		1.0*(sum(NC4G.MOS_2G*NC4G.Samples_2G)) as MOS_2G_Num,
		sum(NC4G.Samples_2G) as MOS_2G_Samples,
		1.0*(sum(NC4G.MOS_3G*NC4G.Samples_3G)) as MOS_3G_Num,
		sum(NC4G.Samples_3G) as MOS_3G_Samples,
		1.0*(sum(NC4G.MOS_GSM900*NC4G.Samples_GSM900)) as MOS_GSM_Num,
		sum(NC4G.Samples_GSM900) as MOS_GSM_Samples,
		1.0*(sum(NC4G.MOS_GSM1800*NC4G.Samples_GSM1800)) as MOS_DCS_Num,
		sum(NC4G.Samples_GSM1800) as MOS_DCS_Samples,
		1.0*(sum(NC4G.MOS_UMTS900*NC4G.Samples_UMTS900)) as MOS_UMTS900_Num,
		sum(NC4G.Samples_UMTS900) as MOS_UMTS900_Samples,
		1.0*(sum(NC4G.MOS_UMTS2100*NC4G.Samples_UMTS2100)) as MOS_UMTS2100_Num,
		sum(NC4G.Samples_UMTS2100) as MOS_UMTS2100_Samples,

		sum(NC4G.Duration_UMTS2100) as Call_duration_UMTS2100,
		sum(NC4G.Duration_UMTS900) as Call_duration_UMTS900,
		sum(NC4G.Duration_GSM900) as Call_duration_GSM,
		sum(NC4G.Duration_GSM1800) as Call_duration_DCS,

		sum(NC4G.[Duration_4G]) as Call_Duration_4G,
		sum(NC4G.[Duration_LTE2600]) as Call_Duration_LTE2600,
		sum(NC4G.[Duration_LTE2100]) as Call_Duration_LTE2100,
		sum(NC4G.[Duration_LTE1800]) as Call_Duration_LTE1800,
		sum(NC4G.[Duration_LTE800]) as Call_Duration_LTE800,

		-------------------------------------
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end as Region_Road_VF,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end as Region_Road_OSP,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]	

	from [AGGRVoice4G].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs] cst
			left outer join [AGGRVoice4G].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs_4G] NC4G on (isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')=isnull(NC4G.parcel,'0.00000 Long, 0.00000 Lat') and cst.mnc=NC4G.mnc and cst.Date_Reporting=NC4G.Date_Reporting and cst.entidad=NC4G.entidad and cst.Aggr_Type=NC4G.Aggr_Type and cst.Report_Type=NC4G.Report_Type and cst.meas_round=NC4G.meas_round) 
		,[AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,cst.mnc,cst.meas_round,cst.Date_Reporting,cst.Week_Reporting,cst.entidad,cst.Report_Type,cst.aggr_type
		, cst.calltype,	cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]--,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_VF end,
		--case when cst.entidad like 'AVE-%' or cst.entidad like 'MAD-___-R[0-9]%' then  'AVE' else cst.Region_OSP end	

	---------
	-- Road 4GOnly:
	insert into _RI_Voice_cst_csfb
	select 
		cst.calltype as Calltype, 
		p.codigo_ine, 'Roads' vf_environment,cst.mnc,cst.meas_round,cst.Date_Reporting as meas_date,cst.Week_Reporting as meas_week, 
		'Road 4GOnly' as meas_Tech, 1 as info_available,cst.entidad as vf_entity,cst.Report_Type,cst.aggr_type,

		SUM(NC4G.Calls_CST_MOMT_ALERT_UMTS) as CST_ALERTING_UMTS_samples,
		SUM(NC4G.Calls_CST_MOMT_ALERT_UMTS900) as CST_ALERTING_UMTS900_samples,
		SUM(NC4G.Calls_CST_MOMT_ALERT_UMTS2100) as CST_ALERTING_UMTS2100_samples,
		SUM(NC4G.Calls_CST_MOMT_ALERT_GSM) as CST_ALERTING_GSM_samples,
		SUM(NC4G.Calls_CST_MOMT_ALERT_GSM900) as CST_ALERTING_GSM900_samples,
		SUM(NC4G.Calls_CST_MOMT_ALERT_GSM1800) as CST_ALERTING_GSM1800_samples,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_UMTS*NC4G.Calls_CST_MOMT_ALERT_UMTS)) as CST_ALERTING_UMTS_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_UMTS900*NC4G.Calls_CST_MOMT_ALERT_UMTS900)) as CST_ALERTING_UMTS900_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_UMTS2100*NC4G.Calls_CST_MOMT_ALERT_UMTS2100)) as CST_ALERTING_UMTS2100_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_GSM*NC4G.Calls_CST_MOMT_ALERT_GSM)) as CST_ALERTING_GSM_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_GSM900*NC4G.Calls_CST_MOMT_ALERT_GSM900)) as CST_ALERTING_GSM900_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_ALERT_GSM1800*NC4G.Calls_CST_MOMT_ALERT_GSM1800)) as CST_ALERTING_GSM1800_NUM,

		SUM(NC4G.Calls_CST_MOMT_CONNECT_UMTS) as CST_CONNECT_UMTS_samples,
		SUM(NC4G.Calls_CST_MOMT_CONNECT_UMTS900) as CST_CONNECT_UMTS900_samples,
		SUM(NC4G.Calls_CST_MOMT_CONNECT_UMTS2100) as CST_CONNECT_UMTS2100_samples,
		SUM(NC4G.Calls_CST_MOMT_CONNECT_GSM) as CST_CONNECT_GSM_samples,
		SUM(NC4G.Calls_CST_MOMT_CONNECT_GSM900) as CST_CONNECT_GSM900_samples,
		SUM(NC4G.Calls_CST_MOMT_CONNECT_GSM1800) as CST_CONNECT_GSM1800_samples,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_UMTS*NC4G.Calls_CST_MOMT_CONNECT_UMTS)) as CST_CONNECT_UMTS_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_UMTS900*NC4G.Calls_CST_MOMT_CONNECT_UMTS900)) as CST_CONNECT_UMTS900_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_UMTS2100*NC4G.Calls_CST_MOMT_CONNECT_UMTS2100)) as CST_CONNECT_UMTS2100_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_GSM*NC4G.Calls_CST_MOMT_CONNECT_GSM)) as CST_CONNECT_GSM_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_GSM900*NC4G.Calls_CST_MOMT_CONNECT_GSM900)) as CST_CONNECT_GSM900_NUM,
		0.001*(1000.0*SUM(NC4G.CST_MOMT_CONNECT_GSM1800*NC4G.Calls_CST_MOMT_CONNECT_GSM1800)) as CST_CONNECT_GSM1800_NUM,

		sum(NC4G.Calls_CSFB_MOMT) as CSFB_duration_samples,
		0.001*(1000.0*sum(NC4G.Calls_CSFB_MOMT*NC4G.CSFB_MOMT)) as CSFB_duration_num,

		1.0*(sum(NC4G.MOS_2G*NC4G.Samples_2G)) as MOS_2G_Num,
		sum(NC4G.Samples_2G) as MOS_2G_Samples,
		1.0*(sum(NC4G.MOS_3G*NC4G.Samples_3G)) as MOS_3G_Num,
		sum(NC4G.Samples_3G) as MOS_3G_Samples,
		1.0*(sum(NC4G.MOS_GSM900*NC4G.Samples_GSM900)) as MOS_GSM_Num,
		sum(NC4G.Samples_GSM900) as MOS_GSM_Samples,
		1.0*(sum(NC4G.MOS_GSM1800*NC4G.Samples_GSM1800)) as MOS_DCS_Num,
		sum(NC4G.Samples_GSM1800) as MOS_DCS_Samples,
		1.0*(sum(NC4G.MOS_UMTS900*NC4G.Samples_UMTS900)) as MOS_UMTS900_Num,
		sum(NC4G.Samples_UMTS900) as MOS_UMTS900_Samples,
		1.0*(sum(NC4G.MOS_UMTS2100*NC4G.Samples_UMTS2100)) as MOS_UMTS2100_Num,
		sum(NC4G.Samples_UMTS2100) as MOS_UMTS2100_Samples,

		sum(NC4G.Duration_UMTS2100) as Call_duration_UMTS2100,
		sum(NC4G.Duration_UMTS900) as Call_duration_UMTS900,
		sum(NC4G.Duration_GSM900) as Call_duration_GSM,
		sum(NC4G.Duration_GSM1800) as Call_duration_DCS,

		sum(NC4G.[Duration_4G]) as Call_Duration_4G,
		sum(NC4G.[Duration_LTE2600]) as Call_Duration_LTE2600,
		sum(NC4G.[Duration_LTE2100]) as Call_Duration_LTE2100,
		sum(NC4G.[Duration_LTE1800]) as Call_Duration_LTE1800,
		sum(NC4G.[Duration_LTE800]) as Call_Duration_LTE800,
		-------------------------------------
		--cst.Region_VF as Region_Road_VF, cst.Region_OSP as Region_Road_OSP,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]	

	from [AGGRVoice4G_Road].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs] cst
		 left outer join [AGGRVoice4G_Road].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs_4G] NC4G on (isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')=isnull(NC4G.parcel,'0.00000 Long, 0.00000 Lat') and cst.mnc=NC4G.mnc and cst.Date_Reporting=NC4G.Date_Reporting and cst.entidad=NC4G.entidad and cst.Aggr_Type=NC4G.Aggr_Type and cst.Report_Type=NC4G.Report_Type and cst.meas_round=NC4G.meas_round)
		, [AGRIDS].[dbo].vlcc_parcelas_osp p
		where p.parcela=isnull(cst.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,cst.mnc,cst.meas_round,cst.Date_Reporting,cst.Week_Reporting,cst.entidad,cst.Report_Type,cst.aggr_type, cst.calltype,
		cst.[ASideDevice], cst.[BSideDevice], cst.[SWVersion]--, cst.Region_VF, cst.Region_OSP	

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 4.2 CST TECNOLOGIA y CSFB duration 4GOnly y 4GOnly_Road', getdate()
	 

	--------------------------------------------------------------------------------------
	/*		4.3	Se añade info VOLTE - ALL, 4G, RealVOLTE, 3G							*/
	-------------------------------------------------------------------------------------- 
	print '4.3 CST TECNOLOGIA y CSFB duration VOLTE - ALL, 4G, RealVOLTE, 3G'
	-----------	
	-- VOLTE ALL:
	insert into _RI_Voice_cst_csfb
	select 
		volte.calltype as Calltype, 
		p.codigo_ine,  
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment,volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE ALL Road' 
			else 'VOLTE ALL' end as meas_Tech, 1 as info_available,volte.entidad as vf_entity,volte.Report_Type,volte.aggr_type,

		SUM(volte.Calls_CST_MOMT_ALERT_UMTS) as CST_ALERTING_UMTS_samples,
		SUM(volte.Calls_CST_MOMT_ALERT_UMTS900) as CST_ALERTING_UMTS900_samples,
		SUM(volte.Calls_CST_MOMT_ALERT_UMTS2100) as CST_ALERTING_UMTS2100_samples,
		SUM(volte.Calls_CST_MOMT_ALERT_GSM) as CST_ALERTING_GSM_samples,
		SUM(volte.Calls_CST_MOMT_ALERT_GSM900) as CST_ALERTING_GSM900_samples,
		SUM(volte.Calls_CST_MOMT_ALERT_GSM1800) as CST_ALERTING_GSM1800_samples,
		0.001*(1000.0*SUM(volte.CST_MOMT_ALERT_UMTS*volte.Calls_CST_MOMT_ALERT_UMTS)) as CST_ALERTING_UMTS_NUM,
		0.001*(1000.0*SUM(volte.CST_MOMT_ALERT_UMTS900*volte.Calls_CST_MOMT_ALERT_UMTS900)) as CST_ALERTING_UMTS900_NUM,
		0.001*(1000.0*SUM(volte.CST_MOMT_ALERT_UMTS2100*volte.Calls_CST_MOMT_ALERT_UMTS2100)) as CST_ALERTING_UMTS2100_NUM,
		0.001*(1000.0*SUM(volte.CST_MOMT_ALERT_GSM*volte.Calls_CST_MOMT_ALERT_GSM)) as CST_ALERTING_GSM_NUM,
		0.001*(1000.0*SUM(volte.CST_MOMT_ALERT_GSM900*volte.Calls_CST_MOMT_ALERT_GSM900)) as CST_ALERTING_GSM900_NUM,
		0.001*(1000.0*SUM(volte.CST_MOMT_ALERT_GSM1800*volte.Calls_CST_MOMT_ALERT_GSM1800)) as CST_ALERTING_GSM1800_NUM,

		SUM(volte.Calls_CST_MOMT_CONNECT_UMTS) as CST_CONNECT_UMTS_samples,
		SUM(volte.Calls_CST_MOMT_CONNECT_UMTS900) as CST_CONNECT_UMTS900_samples,
		SUM(volte.Calls_CST_MOMT_CONNECT_UMTS2100) as CST_CONNECT_UMTS2100_samples,
		SUM(volte.Calls_CST_MOMT_CONNECT_GSM) as CST_CONNECT_GSM_samples,
		SUM(volte.Calls_CST_MOMT_CONNECT_GSM900) as CST_CONNECT_GSM900_samples,
		SUM(volte.Calls_CST_MOMT_CONNECT_GSM1800) as CST_CONNECT_GSM1800_samples,
		0.001*(1000.0*SUM(volte.CST_MOMT_CONNECT_UMTS*volte.Calls_CST_MOMT_CONNECT_UMTS)) as CST_CONNECT_UMTS_NUM,
		0.001*(1000.0*SUM(volte.CST_MOMT_CONNECT_UMTS900*volte.Calls_CST_MOMT_CONNECT_UMTS900)) as CST_CONNECT_UMTS900_NUM,
		0.001*(1000.0*SUM(volte.CST_MOMT_CONNECT_UMTS2100*volte.Calls_CST_MOMT_CONNECT_UMTS2100)) as CST_CONNECT_UMTS2100_NUM,
		0.001*(1000.0*SUM(volte.CST_MOMT_CONNECT_GSM*volte.Calls_CST_MOMT_CONNECT_GSM)) as CST_CONNECT_GSM_NUM,
		0.001*(1000.0*SUM(volte.CST_MOMT_CONNECT_GSM900*volte.Calls_CST_MOMT_CONNECT_GSM900)) as CST_CONNECT_GSM900_NUM,
		0.001*(1000.0*SUM(volte.CST_MOMT_CONNECT_GSM1800*volte.Calls_CST_MOMT_CONNECT_GSM1800)) as CST_CONNECT_GSM1800_NUM,

		sum(volte.Calls_CSFB_MOMT) as CSFB_duration_samples,
		0.001*(1000.0*sum(volte.Calls_CSFB_MOMT*volte.CSFB_MOMT)) as CSFB_duration_num,

		1.0*(sum(volte.MOS_2G*volte.Samples_2G)) as MOS_2G_Num,
		sum(volte.Samples_2G) as MOS_2G_Samples,
		1.0*(sum(volte.MOS_3G*volte.Samples_3G)) as MOS_3G_Num,
		sum(volte.Samples_3G) as MOS_3G_Samples,
		1.0*(sum(volte.MOS_GSM900*volte.Samples_GSM900)) as MOS_GSM_Num,
		sum(volte.Samples_GSM900) as MOS_GSM_Samples,
		1.0*(sum(volte.MOS_GSM1800*volte.Samples_GSM1800)) as MOS_DCS_Num,
		sum(volte.Samples_GSM1800) as MOS_DCS_Samples,
		1.0*(sum(volte.MOS_UMTS900*volte.Samples_UMTS900)) as MOS_UMTS900_Num,
		sum(volte.Samples_UMTS900) as MOS_UMTS900_Samples,
		1.0*(sum(volte.MOS_UMTS2100*volte.Samples_UMTS2100)) as MOS_UMTS2100_Num,
		sum(volte.Samples_UMTS2100) as MOS_UMTS2100_Samples,

		sum(volte.Duration_UMTS2100) as Call_duration_UMTS2100,
		sum(volte.Duration_UMTS900) as Call_duration_UMTS900,
		sum(volte.Duration_GSM900) as Call_duration_GSM,
		sum(volte.Duration_GSM1800) as Call_duration_DCS,
	
		sum(volte.[Duration_4G]) as Call_Duration_4G,
		sum(volte.[Duration_LTE2600]) as Call_Duration_LTE2600,
		sum(volte.[Duration_LTE2100]) as Call_Duration_LTE2100,
		sum(volte.[Duration_LTE1800]) as Call_Duration_LTE1800,
		sum(volte.[Duration_LTE800]) as Call_Duration_LTE800,

		-------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]	

	from [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs] volte, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end, volte.mnc,volte.meas_round,volte.Date_Reporting,volte.Week_Reporting, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE ALL Road' 
			else 'VOLTE ALL' end,volte.entidad,volte.Report_Type,volte.aggr_type, 
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	---------
	-- VOLTE 4G: 
	insert into _RI_Voice_cst_csfb
	select 
		volte.calltype as Calltype, 
		p.codigo_ine,   
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment,volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 4G Road' 
			else 'VOLTE 4G' end as meas_Tech, 1 as info_available,volte.entidad as vf_entity,volte.Report_Type,volte.aggr_type,

		SUM(volte4G.Calls_CST_MOMT_ALERT_UMTS) as CST_ALERTING_UMTS_samples,
		SUM(volte4G.Calls_CST_MOMT_ALERT_UMTS900) as CST_ALERTING_UMTS900_samples,
		SUM(volte4G.Calls_CST_MOMT_ALERT_UMTS2100) as CST_ALERTING_UMTS2100_samples,
		SUM(volte4G.Calls_CST_MOMT_ALERT_GSM) as CST_ALERTING_GSM_samples,
		SUM(volte4G.Calls_CST_MOMT_ALERT_GSM900) as CST_ALERTING_GSM900_samples,
		SUM(volte4G.Calls_CST_MOMT_ALERT_GSM1800) as CST_ALERTING_GSM1800_samples,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_ALERT_UMTS*volte4G.Calls_CST_MOMT_ALERT_UMTS)) as CST_ALERTING_UMTS_NUM,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_ALERT_UMTS900*volte4G.Calls_CST_MOMT_ALERT_UMTS900)) as CST_ALERTING_UMTS900_NUM,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_ALERT_UMTS2100*volte4G.Calls_CST_MOMT_ALERT_UMTS2100)) as CST_ALERTING_UMTS2100_NUM,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_ALERT_GSM*volte4G.Calls_CST_MOMT_ALERT_GSM)) as CST_ALERTING_GSM_NUM,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_ALERT_GSM900*volte4G.Calls_CST_MOMT_ALERT_GSM900)) as CST_ALERTING_GSM900_NUM,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_ALERT_GSM1800*volte4G.Calls_CST_MOMT_ALERT_GSM1800)) as CST_ALERTING_GSM1800_NUM,

		SUM(volte4G.Calls_CST_MOMT_CONNECT_UMTS) as CST_CONNECT_UMTS_samples,
		SUM(volte4G.Calls_CST_MOMT_CONNECT_UMTS900) as CST_CONNECT_UMTS900_samples,
		SUM(volte4G.Calls_CST_MOMT_CONNECT_UMTS2100) as CST_CONNECT_UMTS2100_samples,
		SUM(volte4G.Calls_CST_MOMT_CONNECT_GSM) as CST_CONNECT_GSM_samples,
		SUM(volte4G.Calls_CST_MOMT_CONNECT_GSM900) as CST_CONNECT_GSM900_samples,
		SUM(volte4G.Calls_CST_MOMT_CONNECT_GSM1800) as CST_CONNECT_GSM1800_samples,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_CONNECT_UMTS*volte4G.Calls_CST_MOMT_CONNECT_UMTS)) as CST_CONNECT_UMTS_NUM,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_CONNECT_UMTS900*volte4G.Calls_CST_MOMT_CONNECT_UMTS900)) as CST_CONNECT_UMTS900_NUM,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_CONNECT_UMTS2100*volte4G.Calls_CST_MOMT_CONNECT_UMTS2100)) as CST_CONNECT_UMTS2100_NUM,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_CONNECT_GSM*volte4G.Calls_CST_MOMT_CONNECT_GSM)) as CST_CONNECT_GSM_NUM,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_CONNECT_GSM900*volte4G.Calls_CST_MOMT_CONNECT_GSM900)) as CST_CONNECT_GSM900_NUM,
		0.001*(1000.0*SUM(volte4G.CST_MOMT_CONNECT_GSM1800*volte4G.Calls_CST_MOMT_CONNECT_GSM1800)) as CST_CONNECT_GSM1800_NUM,

		sum(volte4G.Calls_CSFB_MOMT) as CSFB_duration_samples,
		0.001*(1000.0*sum(volte4G.Calls_CSFB_MOMT*volte4G.CSFB_MOMT)) as CSFB_duration_num,

		1.0*(sum(volte4G.MOS_2G*volte4G.Samples_2G)) as MOS_2G_Num,
		sum(volte4G.Samples_2G) as MOS_2G_Samples,
		1.0*(sum(volte4G.MOS_3G*volte4G.Samples_3G)) as MOS_3G_Num,
		sum(volte4G.Samples_3G) as MOS_3G_Samples,
		1.0*(sum(volte4G.MOS_GSM900*volte4G.Samples_GSM900)) as MOS_GSM_Num,
		sum(volte4G.Samples_GSM900) as MOS_GSM_Samples,
		1.0*(sum(volte4G.MOS_GSM1800*volte4G.Samples_GSM1800)) as MOS_DCS_Num,
		sum(volte4G.Samples_GSM1800) as MOS_DCS_Samples,
		1.0*(sum(volte4G.MOS_UMTS900*volte4G.Samples_UMTS900)) as MOS_UMTS900_Num,
		sum(volte4G.Samples_UMTS900) as MOS_UMTS900_Samples,
		1.0*(sum(volte4G.MOS_UMTS2100*volte4G.Samples_UMTS2100)) as MOS_UMTS2100_Num,
		sum(volte4G.Samples_UMTS2100) as MOS_UMTS2100_Samples,

		sum(volte4G.Duration_UMTS2100) as Call_duration_UMTS2100,
		sum(volte4G.Duration_UMTS900) as Call_duration_UMTS900,
		sum(volte4G.Duration_GSM900) as Call_duration_GSM,
		sum(volte4G.Duration_GSM1800) as Call_duration_DCS,

		sum(volte4G.[Duration_4G]) as Call_Duration_4G,
		sum(volte4G.[Duration_LTE2600]) as Call_Duration_LTE2600,
		sum(volte4G.[Duration_LTE2100]) as Call_Duration_LTE2100,
		sum(volte4G.[Duration_LTE1800]) as Call_Duration_LTE1800,
		sum(volte4G.[Duration_LTE800]) as Call_Duration_LTE800,

		-------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]	

	from [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs] volte
				LEFT OUTER JOIN [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs_4G] volte4G on (isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')=isnull(volte4G.parcel,'0.00000 Long, 0.00000 Lat') and volte.mnc=volte4G.mnc and volte.Date_Reporting=volte4G.Date_Reporting and volte.entidad=volte4G.entidad and volte.Aggr_Type=volte4G.Aggr_Type and volte.Report_Type=volte4G.Report_Type and volte.meas_round=volte4G.meas_round)
		, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,  
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end, volte.mnc,volte.meas_round,volte.Date_Reporting,volte.Week_Reporting, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 4G Road' 
			else 'VOLTE 4G' end,volte.entidad,volte.Report_Type,volte.aggr_type, 
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%'  then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]	

	---------
	-- VOLTE RealVOLTE:
	insert into _RI_Voice_cst_csfb
	select 
		volte.calltype as Calltype, 
		p.codigo_ine,  
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end as vf_environment,volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE RealVOLTE Road' 
			else 'VOLTE RealVOLTE' end as meas_Tech, 1 as info_available,volte.entidad as vf_entity,volte.Report_Type,volte.aggr_type,

		SUM(volteRV.Calls_CST_MOMT_ALERT_UMTS) as CST_ALERTING_UMTS_samples,
		SUM(volteRV.Calls_CST_MOMT_ALERT_UMTS900) as CST_ALERTING_UMTS900_samples,
		SUM(volteRV.Calls_CST_MOMT_ALERT_UMTS2100) as CST_ALERTING_UMTS2100_samples,
		SUM(volteRV.Calls_CST_MOMT_ALERT_GSM) as CST_ALERTING_GSM_samples,
		SUM(volteRV.Calls_CST_MOMT_ALERT_GSM900) as CST_ALERTING_GSM900_samples,
		SUM(volteRV.Calls_CST_MOMT_ALERT_GSM1800) as CST_ALERTING_GSM1800_samples,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_ALERT_UMTS*volteRV.Calls_CST_MOMT_ALERT_UMTS)) as CST_ALERTING_UMTS_NUM,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_ALERT_UMTS900*volteRV.Calls_CST_MOMT_ALERT_UMTS900)) as CST_ALERTING_UMTS900_NUM,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_ALERT_UMTS2100*volteRV.Calls_CST_MOMT_ALERT_UMTS2100)) as CST_ALERTING_UMTS2100_NUM,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_ALERT_GSM*volteRV.Calls_CST_MOMT_ALERT_GSM)) as CST_ALERTING_GSM_NUM,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_ALERT_GSM900*volteRV.Calls_CST_MOMT_ALERT_GSM900)) as CST_ALERTING_GSM900_NUM,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_ALERT_GSM1800*volteRV.Calls_CST_MOMT_ALERT_GSM1800)) as CST_ALERTING_GSM1800_NUM,

		SUM(volteRV.Calls_CST_MOMT_CONNECT_UMTS) as CST_CONNECT_UMTS_samples,
		SUM(volteRV.Calls_CST_MOMT_CONNECT_UMTS900) as CST_CONNECT_UMTS900_samples,
		SUM(volteRV.Calls_CST_MOMT_CONNECT_UMTS2100) as CST_CONNECT_UMTS2100_samples,
		SUM(volteRV.Calls_CST_MOMT_CONNECT_GSM) as CST_CONNECT_GSM_samples,
		SUM(volteRV.Calls_CST_MOMT_CONNECT_GSM900) as CST_CONNECT_GSM900_samples,
		SUM(volteRV.Calls_CST_MOMT_CONNECT_GSM1800) as CST_CONNECT_GSM1800_samples,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_CONNECT_UMTS*volteRV.Calls_CST_MOMT_CONNECT_UMTS)) as CST_CONNECT_UMTS_NUM,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_CONNECT_UMTS900*volteRV.Calls_CST_MOMT_CONNECT_UMTS900)) as CST_CONNECT_UMTS900_NUM,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_CONNECT_UMTS2100*volteRV.Calls_CST_MOMT_CONNECT_UMTS2100)) as CST_CONNECT_UMTS2100_NUM,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_CONNECT_GSM*volteRV.Calls_CST_MOMT_CONNECT_GSM)) as CST_CONNECT_GSM_NUM,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_CONNECT_GSM900*volteRV.Calls_CST_MOMT_CONNECT_GSM900)) as CST_CONNECT_GSM900_NUM,
		0.001*(1000.0*SUM(volteRV.CST_MOMT_CONNECT_GSM1800*volteRV.Calls_CST_MOMT_CONNECT_GSM1800)) as CST_CONNECT_GSM1800_NUM,

		sum(volteRV.Calls_CSFB_MOMT) as CSFB_duration_samples,
		0.001*(1000.0*sum(volteRV.Calls_CSFB_MOMT*volteRV.CSFB_MOMT)) as CSFB_duration_num,

		1.0*(sum(volteRV.MOS_2G*volteRV.Samples_2G)) as MOS_2G_Num,
		sum(volteRV.Samples_2G) as MOS_2G_Samples,
		1.0*(sum(volteRV.MOS_3G*volteRV.Samples_3G)) as MOS_3G_Num,
		sum(volteRV.Samples_3G) as MOS_3G_Samples,
		1.0*(sum(volteRV.MOS_GSM900*volteRV.Samples_GSM900)) as MOS_GSM_Num,
		sum(volteRV.Samples_GSM900) as MOS_GSM_Samples,
		1.0*(sum(volteRV.MOS_GSM1800*volteRV.Samples_GSM1800)) as MOS_DCS_Num,
		sum(volteRV.Samples_GSM1800) as MOS_DCS_Samples,
		1.0*(sum(volteRV.MOS_UMTS900*volteRV.Samples_UMTS900)) as MOS_UMTS900_Num,
		sum(volteRV.Samples_UMTS900) as MOS_UMTS900_Samples,
		1.0*(sum(volteRV.MOS_UMTS2100*volteRV.Samples_UMTS2100)) as MOS_UMTS2100_Num,
		sum(volteRV.Samples_UMTS2100) as MOS_UMTS2100_Samples,

		sum(volteRV.Duration_UMTS2100) as Call_duration_UMTS2100,
		sum(volteRV.Duration_UMTS900) as Call_duration_UMTS900,
		sum(volteRV.Duration_GSM900) as Call_duration_GSM,
		sum(volteRV.Duration_GSM1800) as Call_duration_DCS,

		sum(volteRV.[Duration_4G]) as Call_Duration_4G,
		sum(volteRV.[Duration_LTE2600]) as Call_Duration_LTE2600,
		sum(volteRV.[Duration_LTE2100]) as Call_Duration_LTE2100,
		sum(volteRV.[Duration_LTE1800]) as Call_Duration_LTE1800,
		sum(volteRV.[Duration_LTE800]) as Call_Duration_LTE800,

		-------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]	

	from [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs] volte
				LEFT OUTER JOIN [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs_VOLTE] volteRV on (isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')=isnull(volteRV.parcel,'0.00000 Long, 0.00000 Lat') and volte.mnc=volteRV.mnc and volte.Date_Reporting=volteRV.Date_Reporting and volte.entidad=volteRV.entidad and volte.Aggr_Type=volteRV.Aggr_Type and volte.Report_Type=volteRV.Report_Type and volte.meas_round=volteRV.meas_round)
		, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine,  
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE'
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'	
		 else p.vf_environment end, volte.mnc,volte.meas_round,volte.Date_Reporting,volte.Week_Reporting, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE RealVOLTE Road' 
			else 'VOLTE RealVOLTE' end,volte.entidad,volte.Report_Type,volte.aggr_type, 
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]

	---------
	-- VOLTE 3G:
	insert into _RI_Voice_cst_csfb
	select 
		volte.calltype as Calltype, 
		p.codigo_ine, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE' 
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'
		else p.vf_environment end as vf_environment ,volte.mnc,volte.meas_round,volte.Date_Reporting as meas_date,volte.Week_Reporting as meas_week, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 3G Road' 
			else 'VOLTE 3G' end as meas_Tech, 1 as info_available,volte.entidad as vf_entity,volte.Report_Type,volte.aggr_type,

		SUM(volte3G.Calls_CST_MOMT_ALERT_UMTS) as CST_ALERTING_UMTS_samples,
		SUM(volte3G.Calls_CST_MOMT_ALERT_UMTS900) as CST_ALERTING_UMTS900_samples,
		SUM(volte3G.Calls_CST_MOMT_ALERT_UMTS2100) as CST_ALERTING_UMTS2100_samples,
		SUM(volte3G.Calls_CST_MOMT_ALERT_GSM) as CST_ALERTING_GSM_samples,
		SUM(volte3G.Calls_CST_MOMT_ALERT_GSM900) as CST_ALERTING_GSM900_samples,
		SUM(volte3G.Calls_CST_MOMT_ALERT_GSM1800) as CST_ALERTING_GSM1800_samples,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_ALERT_UMTS*volte3G.Calls_CST_MOMT_ALERT_UMTS)) as CST_ALERTING_UMTS_NUM,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_ALERT_UMTS900*volte3G.Calls_CST_MOMT_ALERT_UMTS900)) as CST_ALERTING_UMTS900_NUM,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_ALERT_UMTS2100*volte3G.Calls_CST_MOMT_ALERT_UMTS2100)) as CST_ALERTING_UMTS2100_NUM,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_ALERT_GSM*volte3G.Calls_CST_MOMT_ALERT_GSM)) as CST_ALERTING_GSM_NUM,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_ALERT_GSM900*volte3G.Calls_CST_MOMT_ALERT_GSM900)) as CST_ALERTING_GSM900_NUM,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_ALERT_GSM1800*volte3G.Calls_CST_MOMT_ALERT_GSM1800)) as CST_ALERTING_GSM1800_NUM,

		SUM(volte3G.Calls_CST_MOMT_CONNECT_UMTS) as CST_CONNECT_UMTS_samples,
		SUM(volte3G.Calls_CST_MOMT_CONNECT_UMTS900) as CST_CONNECT_UMTS900_samples,
		SUM(volte3G.Calls_CST_MOMT_CONNECT_UMTS2100) as CST_CONNECT_UMTS2100_samples,
		SUM(volte3G.Calls_CST_MOMT_CONNECT_GSM) as CST_CONNECT_GSM_samples,
		SUM(volte3G.Calls_CST_MOMT_CONNECT_GSM900) as CST_CONNECT_GSM900_samples,
		SUM(volte3G.Calls_CST_MOMT_CONNECT_GSM1800) as CST_CONNECT_GSM1800_samples,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_CONNECT_UMTS*volte3G.Calls_CST_MOMT_CONNECT_UMTS)) as CST_CONNECT_UMTS_NUM,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_CONNECT_UMTS900*volte3G.Calls_CST_MOMT_CONNECT_UMTS900)) as CST_CONNECT_UMTS900_NUM,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_CONNECT_UMTS2100*volte3G.Calls_CST_MOMT_CONNECT_UMTS2100)) as CST_CONNECT_UMTS2100_NUM,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_CONNECT_GSM*volte3G.Calls_CST_MOMT_CONNECT_GSM)) as CST_CONNECT_GSM_NUM,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_CONNECT_GSM900*volte3G.Calls_CST_MOMT_CONNECT_GSM900)) as CST_CONNECT_GSM900_NUM,
		0.001*(1000.0*SUM(volte3G.CST_MOMT_CONNECT_GSM1800*volte3G.Calls_CST_MOMT_CONNECT_GSM1800)) as CST_CONNECT_GSM1800_NUM,

		sum(volte3G.Calls_CSFB_MOMT) as CSFB_duration_samples,
		0.001*(1000.0*sum(volte3G.Calls_CSFB_MOMT*volte3G.CSFB_MOMT)) as CSFB_duration_num,

		1.0*(sum(volte3G.MOS_2G*volte3G.Samples_2G)) as MOS_2G_Num,
		sum(volte3G.Samples_2G) as MOS_2G_Samples,
		1.0*(sum(volte3G.MOS_3G*volte3G.Samples_3G)) as MOS_3G_Num,
		sum(volte3G.Samples_3G) as MOS_3G_Samples,
		1.0*(sum(volte3G.MOS_GSM900*volte3G.Samples_GSM900)) as MOS_GSM_Num,
		sum(volte3G.Samples_GSM900) as MOS_GSM_Samples,
		1.0*(sum(volte3G.MOS_GSM1800*volte3G.Samples_GSM1800)) as MOS_DCS_Num,
		sum(volte3G.Samples_GSM1800) as MOS_DCS_Samples,
		1.0*(sum(volte3G.MOS_UMTS900*volte3G.Samples_UMTS900)) as MOS_UMTS900_Num,
		sum(volte3G.Samples_UMTS900) as MOS_UMTS900_Samples,
		1.0*(sum(volte3G.MOS_UMTS2100*volte3G.Samples_UMTS2100)) as MOS_UMTS2100_Num,
		sum(volte3G.Samples_UMTS2100) as MOS_UMTS2100_Samples,

		sum(volte3G.Duration_UMTS2100) as Call_duration_UMTS2100,
		sum(volte3G.Duration_UMTS900) as Call_duration_UMTS900,
		sum(volte3G.Duration_GSM900) as Call_duration_GSM,
		sum(volte3G.Duration_GSM1800) as Call_duration_DCS,

		sum(volte3G.[Duration_4G]) as Call_Duration_4G,
		sum(volte3G.[Duration_LTE2600]) as Call_Duration_LTE2600,
		sum(volte3G.[Duration_LTE2100]) as Call_Duration_LTE2100,
		sum(volte3G.[Duration_LTE1800]) as Call_Duration_LTE1800,
		sum(volte3G.[Duration_LTE800]) as Call_Duration_LTE800,

		-------------------------------------
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end as Region_Road_VF,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end as Region_Road_OSP,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]	

	from  [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs] volte
				LEFT OUTER JOIN [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_NEW_KPIs_3G] volte3G on  (isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')=isnull(Volte3G.parcel,'0.00000 Long, 0.00000 Lat') and volte.mnc=Volte3G.mnc and volte.Date_Reporting=Volte3G.Date_Reporting and volte.entidad=Volte3G.entidad and volte.Aggr_Type=Volte3G.Aggr_Type and volte.Report_Type=Volte3G.Report_Type and volte.meas_round=Volte3G.meas_round)
			, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(volte.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, 
		case 
			when volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then 'AVE' 
			when volte.entidad like 'A[1-7]%-%-R%' then 'Roads'
		else p.vf_environment end, 
		volte.mnc,volte.meas_round,volte.Date_Reporting,volte.Week_Reporting, 
		case when volte.entidad like 'A[1-7]%-%-R%' then 'VOLTE 3G Road' 
			else 'VOLTE 3G' end,volte.entidad,volte.Report_Type,volte.aggr_type, 
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_VF
		--else null end,
		--case 
		--	when volte.entidad like 'A[1-7]%-%-R%' or volte.entidad like 'AVE-%' or volte.entidad like 'MAD-___-R[0-9]%' then volte.Region_OSP
		--else null end, 
		volte.calltype,
		volte.[ASideDevice], volte.[BSideDevice], volte.[SWVersion]	

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 4.3 CST TECNOLOGIA y CSFB duration VOLTE - ALL, 4G, RealVOLTE, 3G', getdate()


	------------------------------------------------------------------------------
	-- 5. COVERAGE 4G y Road 4G
	------------------------------------------------------------------------------ 
	print '5. COVERAGE 4G y Road 4G'
	-----------
	select 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week,
	   'Cover' as meas_Tech, entidad as vf_entity, c.report_type as report_Type, 'GRID' as aggr_type
		,sum([coverage_den]) [coverage4G_den]
		,case when sum(LTE_Samples_ProbCobInd) is not null then sum([coverage_den]) end [coverage4G_den_ProbCob]		-- se usara este por los nulos de los AVEs
		,sum([samples_4Gcov_num]) [samples_4Gcov_num]
		,sum([samples_L800cov_num]) [samples_L800cov_num]
		,sum([samples_L1800cov_num]) [samples_L1800cov_num]
		,sum([samples_L2100cov_num]) [samples_L2100cov_num]
		,sum([samples_L2600cov_num]) [samples_L2600cov_num]
		,sum([samples_L800L1800cov_num]) [samples_L800L1800cov_num]
		,sum([samples_L800L2100cov_num]) [samples_L800L2100cov_num]
		,sum([samples_L800L2600cov_num]) [samples_L800L2600cov_num]
		,sum([samples_L1800L2100cov_num]) [samples_L1800L2100cov_num]
		,sum([samples_L1800L2600cov_num]) [samples_L1800L2600cov_num]
		,sum([samples_L2100L2600cov_num]) [samples_L2100L2600cov_num]
		,sum([samples_L800L1800L2100cov_num]) [samples_L800L1800L2100cov_num]
		,sum([samples_L800L1800L2600cov_num]) [samples_L800L1800L2600cov_num]
		,sum([samples_L1800L2100L2600cov_num]) [samples_L1800L2100L2600cov_num]
		,sum([samples_L800L1800L2100L2600cov_num]) [samples_L800L1800L2100L2600cov_num]
		,sum([samples_L800L2100L2600cov_num]) [samples_L800L2100L2600cov_num]	  
		,sum(samples_L2100_BW5cov_num) samples_L2100_BW5cov_num
		,sum(samples_L2100_BW10cov_num) samples_L2100_BW10cov_num
		,sum(samples_L2100_BW15cov_num) samples_L2100_BW15cov_num
		,sum(samples_L1800_BW10cov_num) samples_L1800_BW10cov_num
		,sum(samples_L1800_BW15cov_num) samples_L1800_BW15cov_num
		,sum(samples_L1800_BW20cov_num) samples_L1800_BW20cov_num
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG],0)))/10.0)*samplesAVG)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG)) as 'cobertura_AVG_4G_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG L800],0)))/10.0)*samplesAVG_L800)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_L800)) as 'cobertura_AVG_L800_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG L1800],0)))/10.0)*samplesAVG_L1800)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_L1800)) as 'cobertura_AVG_L1800_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG L2100],0)))/10.0)*samplesAVG_L2100)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_L2100)) as 'cobertura_AVG_L2100_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG L2600],0)))/10.0)*samplesAVG_L2600)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_L2600)) as 'cobertura_AVG_L2600_Num'
		,sum(samplesAVG) as 'samplesAVG_4G'
		,sum(samplesAVG_L800) as 'samplesAVG_L800'
		,sum(samplesAVG_L1800) as 'samplesAVG_L1800'
		,sum(samplesAVG_L2100) as 'samplesAVG_L2100'
		,sum(samplesAVG_L2600) as 'samplesAVG_L2600'
		,sum(LTE_ProbCobInd*LTE_Samples_ProbCobInd) as LTE_ProbCobInd
		,sum(LTE2600_ProbCobInd*LTE2600_Samples_ProbCobInd) as LTE2600_ProbCobInd
		,sum(LTE2100_ProbCobInd*LTE2100_Samples_ProbCobInd) as LTE2100_ProbCobInd 
		,sum(LTE2100_BW5_ProbCobInd*LTE2100_BW5_Samples_ProbCobInd) as LTE2100_BW5_ProbCobInd
		,sum(LTE2100_BW10_ProbCobInd*LTE2100_BW10_Samples_ProbCobInd) as LTE2100_BW10_ProbCobInd
		,sum(LTE2100_BW15_ProbCobInd*LTE2100_BW15_Samples_ProbCobInd) as LTE2100_BW15_ProbCobInd
		,sum(LTE1800_ProbCobInd*LTE1800_Samples_ProbCobInd) as LTE1800_ProbCobInd
		,sum(LTE1800_BW10_ProbCobInd*LTE1800_BW10_Samples_ProbCobInd) as LTE1800_BW10_ProbCobInd
		,sum(LTE1800_BW15_ProbCobInd*LTE1800_BW15_Samples_ProbCobInd) as LTE1800_BW15_ProbCobInd
		,sum(LTE1800_BW20_ProbCobInd*LTE1800_BW20_Samples_ProbCobInd) as LTE1800_BW20_ProbCobInd
		,sum(LTE800_ProbCobInd*LTE800_Samples_ProbCobInd) as LTE800_ProbCobInd
		,sum(LTE800_1800_ProbCobInd*LTE800_1800_Samples_ProbCobInd) as LTE800_1800_ProbCobInd
		,sum(LTE800_2100_ProbCobInd*LTE800_2100_Samples_ProbCobInd) as LTE800_2100_ProbCobInd
		,sum(LTE800_2600_ProbCobInd*LTE800_2600_Samples_ProbCobInd) as LTE800_2600_ProbCobInd
		,sum(LTE1800_2100_ProbCobInd*LTE1800_2100_Samples_ProbCobInd) as LTE1800_2100_ProbCobInd
		,sum(LTE1800_2600_ProbCobInd*LTE1800_2600_Samples_ProbCobInd) as LTE1800_2600_ProbCobInd
		,sum(LTE2100_2600_ProbCobInd*LTE2100_2600_Samples_ProbCobInd) as LTE2100_2600_ProbCobInd
		,sum(LTE800_1800_2100_ProbCobInd*LTE800_1800_2100_Samples_ProbCobInd) as LTE800_1800_2100_ProbCobInd
		,sum(LTE800_1800_2600_ProbCobInd*LTE800_1800_2600_Samples_ProbCobInd) as LTE800_1800_2600_ProbCobInd
		,sum(LTE800_2100_2600_ProbCobInd*LTE800_2100_2600_Samples_ProbCobInd) as LTE800_2100_2600_ProbCobInd
		,sum(LTE1800_2100_2600_ProbCobInd*LTE1800_2100_2600_Samples_ProbCobInd) as LTE1800_2100_2600_ProbCobInd
		,sum(LTE_Samples_ProbCobInd) as LTE_Samples_ProbCobInd
		,sum(LTE2600_Samples_ProbCobInd) as LTE2600_Samples_ProbCobInd
		,sum(LTE2100_Samples_ProbCobInd) as LTE2100_Samples_ProbCobInd
		,sum(LTE2100_BW5_Samples_ProbCobInd) as LTE2100_BW5_Samples_ProbCobInd
		,sum(LTE2100_BW10_Samples_ProbCobInd) as LTE2100_BW10_Samples_ProbCobInd
		,sum(LTE2100_BW15_Samples_ProbCobInd) as LTE2100_BW15_Samples_ProbCobInd
		,sum(LTE1800_Samples_ProbCobInd) as LTE1800_Samples_ProbCobInd
		,sum(LTE1800_BW10_Samples_ProbCobInd) as LTE1800_BW10_Samples_ProbCobInd
		,sum(LTE1800_BW15_Samples_ProbCobInd) as LTE1800_BW15_Samples_ProbCobInd
		,sum(LTE1800_BW20_Samples_ProbCobInd) as LTE1800_BW20_Samples_ProbCobInd
		,sum(LTE800_Samples_ProbCobInd) as LTE800_Samples_ProbCobInd
		,sum(LTE800_1800_Samples_ProbCobInd) as LTE800_1800_Samples_ProbCobInd
		,sum(LTE800_2100_Samples_ProbCobInd) as LTE800_2100_Samples_ProbCobInd
		,sum(LTE800_2600_Samples_ProbCobInd) as LTE800_2600_Samples_ProbCobInd
		,sum(LTE1800_2100_Samples_ProbCobInd) as LTE1800_2100_Samples_ProbCobInd
		,sum(LTE1800_2600_Samples_ProbCobInd) as LTE1800_2600_Samples_ProbCobInd
		,sum(LTE2100_2600_Samples_ProbCobInd) as LTE2100_2600_Samples_ProbCobInd
		,sum(LTE800_1800_2100_Samples_ProbCobInd) as LTE800_1800_2100_Samples_ProbCobInd
		,sum(LTE800_1800_2600_Samples_ProbCobInd) as LTE800_1800_2600_Samples_ProbCobInd
		,sum(LTE800_2100_2600_Samples_ProbCobInd) as LTE800_2100_2600_Samples_ProbCobInd
		,sum(LTE1800_2100_2600_Samples_ProbCobInd) as LTE1800_2100_2600_Samples_ProbCobInd

		-------------------------------------
		--,case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_VF end as Region_Road_VF
		--,case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_OSP end as Region_Road_OSP
		,cast(null as [nvarchar](255)) as calltype, cast(null as [nvarchar](255)) as ASideDevice, cast(null as [nvarchar](255)) as BSideDevice, cast(null as [nvarchar](255)) as SWVersion

	into _RI_Voice_cober4G
	from	[AGGRCoverage].[dbo].vlcc_cober4G_bands c, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(c.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,
		mnc,meas_round,Date_Reporting,Week_Reporting,entidad, c.report_type--,
		--case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_VF end,
		--case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_OSP end

	---------
	union all 
	select 
		p.codigo_ine, 'Roads' vf_environment,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week,
	   'Road Cover' as meas_Tech, case when report_Type = 'ROAD' then entidad +'-RX' else entidad end as vf_entity, c.report_Type as report_Type, 'GRID' as aggr_type
		,sum([coverage_den]) [coverage4G_den]
		,case when sum(LTE_Samples_ProbCobInd) is not null then sum([coverage_den]) end [coverage4G_den_ProbCob]		-- se usara este por los nulos de los AVEs
		,sum([samples_4Gcov_num]) [samples_4Gcov_num]
		,sum([samples_L800cov_num]) [samples_L800cov_num]
		,sum([samples_L1800cov_num]) [samples_L1800cov_num]
		,sum([samples_L2100cov_num]) [samples_L2100cov_num]
		,sum([samples_L2600cov_num]) [samples_L2600cov_num]
		,sum([samples_L800L1800cov_num]) [samples_L800L1800cov_num]
		,sum([samples_L800L2100cov_num]) [samples_L800L2100cov_num]
		,sum([samples_L800L2600cov_num]) [samples_L800L2600cov_num]
		,sum([samples_L1800L2100cov_num]) [samples_L1800L2100cov_num]
		,sum([samples_L1800L2600cov_num]) [samples_L1800L2600cov_num]
		,sum([samples_L2100L2600cov_num]) [samples_L2100L2600cov_num]
		,sum([samples_L800L1800L2100cov_num]) [samples_L800L1800L2100cov_num]
		,sum([samples_L800L1800L2600cov_num]) [samples_L800L1800L2600cov_num]
		,sum([samples_L1800L2100L2600cov_num]) [samples_L1800L2100L2600cov_num]
		,sum([samples_L800L1800L2100L2600cov_num]) [samples_L800L1800L2100L2600cov_num]
		,sum([samples_L800L2100L2600cov_num]) [samples_L800L2100L2600cov_num]	  
		,sum(samples_L2100_BW5cov_num) samples_L2100_BW5cov_num
		,sum(samples_L2100_BW10cov_num) samples_L2100_BW10cov_num
		,sum(samples_L2100_BW15cov_num) samples_L2100_BW15cov_num
		,sum(samples_L1800_BW10cov_num) samples_L1800_BW10cov_num
		,sum(samples_L1800_BW15cov_num) samples_L1800_BW15cov_num
		,sum(samples_L1800_BW20cov_num) samples_L1800_BW20cov_num
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG],0)))/10.0)*samplesAVG)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG)) as 'cobertura_AVG_4G_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG L800],0)))/10.0)*samplesAVG_L800)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_L800)) as 'cobertura_AVG_L800_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG L1800],0)))/10.0)*samplesAVG_L1800)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_L1800)) as 'cobertura_AVG_L1800_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG L2100],0)))/10.0)*samplesAVG_L2100)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_L2100)) as 'cobertura_AVG_L2100_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG L2600],0)))/10.0)*samplesAVG_L2600)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_L2600)) as 'cobertura_AVG_L2600_Num'
		,sum(samplesAVG) as 'samplesAVG_4G'
		,sum(samplesAVG_L800) as 'samplesAVG_L800'
		,sum(samplesAVG_L1800) as 'samplesAVG_L1800'
		,sum(samplesAVG_L2100) as 'samplesAVG_L2100'
		,sum(samplesAVG_L2600) as 'samplesAVG_L2600'
		,sum(LTE_ProbCobInd*LTE_Samples_ProbCobInd) as LTE_ProbCobInd
		,sum(LTE2600_ProbCobInd*LTE2600_Samples_ProbCobInd) as LTE2600_ProbCobInd
		,sum(LTE2100_ProbCobInd*LTE2100_Samples_ProbCobInd) as LTE2100_ProbCobInd 
		,sum(LTE2100_BW5_ProbCobInd*LTE2100_BW5_Samples_ProbCobInd) as LTE2100_BW5_ProbCobInd
		,sum(LTE2100_BW10_ProbCobInd*LTE2100_BW10_Samples_ProbCobInd) as LTE2100_BW10_ProbCobInd
		,sum(LTE2100_BW15_ProbCobInd*LTE2100_BW15_Samples_ProbCobInd) as LTE2100_BW15_ProbCobInd
		,sum(LTE1800_ProbCobInd*LTE1800_Samples_ProbCobInd) as LTE1800_ProbCobInd
		,sum(LTE1800_BW10_ProbCobInd*LTE1800_BW10_Samples_ProbCobInd) as LTE1800_BW10_ProbCobInd
		,sum(LTE1800_BW15_ProbCobInd*LTE1800_BW15_Samples_ProbCobInd) as LTE1800_BW15_ProbCobInd
		,sum(LTE1800_BW20_ProbCobInd*LTE1800_BW20_Samples_ProbCobInd) as LTE1800_BW20_ProbCobInd
		,sum(LTE800_ProbCobInd*LTE800_Samples_ProbCobInd) as LTE800_ProbCobInd
		,sum(LTE800_1800_ProbCobInd*LTE800_1800_Samples_ProbCobInd) as LTE800_1800_ProbCobInd
		,sum(LTE800_2100_ProbCobInd*LTE800_2100_Samples_ProbCobInd) as LTE800_2100_ProbCobInd
		,sum(LTE800_2600_ProbCobInd*LTE800_2600_Samples_ProbCobInd) as LTE800_2600_ProbCobInd
		,sum(LTE1800_2100_ProbCobInd*LTE1800_2100_Samples_ProbCobInd) as LTE1800_2100_ProbCobInd
		,sum(LTE1800_2600_ProbCobInd*LTE1800_2600_Samples_ProbCobInd) as LTE1800_2600_ProbCobInd
		,sum(LTE2100_2600_ProbCobInd*LTE2100_2600_Samples_ProbCobInd) as LTE2100_2600_ProbCobInd
		,sum(LTE800_1800_2100_ProbCobInd*LTE800_1800_2100_Samples_ProbCobInd) as LTE800_1800_2100_ProbCobInd
		,sum(LTE800_1800_2600_ProbCobInd*LTE800_1800_2600_Samples_ProbCobInd) as LTE800_1800_2600_ProbCobInd
		,sum(LTE800_2100_2600_ProbCobInd*LTE800_2100_2600_Samples_ProbCobInd) as LTE800_2100_2600_ProbCobInd
		,sum(LTE1800_2100_2600_ProbCobInd*LTE1800_2100_2600_Samples_ProbCobInd) as LTE1800_2100_2600_ProbCobInd
		,sum(LTE_Samples_ProbCobInd) as LTE_Samples_ProbCobInd
		,sum(LTE2600_Samples_ProbCobInd) as LTE2600_Samples_ProbCobInd
		,sum(LTE2100_Samples_ProbCobInd) as LTE2100_Samples_ProbCobInd
		,sum(LTE2100_BW5_Samples_ProbCobInd) as LTE2100_BW5_Samples_ProbCobInd
		,sum(LTE2100_BW10_Samples_ProbCobInd) as LTE2100_BW10_Samples_ProbCobInd
		,sum(LTE2100_BW15_Samples_ProbCobInd) as LTE2100_BW15_Samples_ProbCobInd
		,sum(LTE1800_Samples_ProbCobInd) as LTE1800_Samples_ProbCobInd
		,sum(LTE1800_BW10_Samples_ProbCobInd) as LTE1800_BW10_Samples_ProbCobInd
		,sum(LTE1800_BW15_Samples_ProbCobInd) as LTE1800_BW15_Samples_ProbCobInd
		,sum(LTE1800_BW20_Samples_ProbCobInd) as LTE1800_BW20_Samples_ProbCobInd
		,sum(LTE800_Samples_ProbCobInd) as LTE800_Samples_ProbCobInd
		,sum(LTE800_1800_Samples_ProbCobInd) as LTE800_1800_Samples_ProbCobInd
		,sum(LTE800_2100_Samples_ProbCobInd) as LTE800_2100_Samples_ProbCobInd
		,sum(LTE800_2600_Samples_ProbCobInd) as LTE800_2600_Samples_ProbCobInd
		,sum(LTE1800_2100_Samples_ProbCobInd) as LTE1800_2100_Samples_ProbCobInd
		,sum(LTE1800_2600_Samples_ProbCobInd) as LTE1800_2600_Samples_ProbCobInd
		,sum(LTE2100_2600_Samples_ProbCobInd) as LTE2100_2600_Samples_ProbCobInd
		,sum(LTE800_1800_2100_Samples_ProbCobInd) as LTE800_1800_2100_Samples_ProbCobInd
		,sum(LTE800_1800_2600_Samples_ProbCobInd) as LTE800_1800_2600_Samples_ProbCobInd
		,sum(LTE800_2100_2600_Samples_ProbCobInd) as LTE800_2100_2600_Samples_ProbCobInd
		,sum(LTE1800_2100_2600_Samples_ProbCobInd) as LTE1800_2100_2600_Samples_ProbCobInd

		-------------------------------------
		--,c.Region_VF as Region_Road_VF, c.Region_OSP as Region_Road_OSP
		,cast(null as [nvarchar](255)) as calltype, cast(null as [nvarchar](255)) as ASideDevice, cast(null as [nvarchar](255)) as BSideDevice, cast(null as [nvarchar](255)) as SWVersion

	from	[AGGRCoverage_ROAD].[dbo].vlcc_cober4G_bands c, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(c.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, mnc,meas_round,Date_Reporting,Week_Reporting,entidad, c.report_type--, c.Region_VF, c.Region_OSP

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 5. COVERAGE 4G y Road 4G', getdate()


	------------------------------------------------------------------------------
	-- 6. COVERAGE 3G y Road 3G
	------------------------------------------------------------------------------ 
	print '6. COVERAGE 3G y Road 3G'
	-----------
	select 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week,
	   'Cover' as meas_Tech,  entidad as vf_entity, c.report_Type as report_Type, 'GRID' as aggr_type
		,sum([coverage_den]) as [coverage3G_den]
		,case when sum([UMTS_Samples_ProbCobInd]) is not null then sum([coverage_den]) end [coverage3G_den_ProbCob]		-- se usara este por los nulos de los AVEs
		,sum([samples_3Gcov_num]) [samples_3Gcov_num]
		,sum([samples_U2100cov_num]) [samples_U2100cov_num]
		,sum([samples_UMTS900cov_num]) [samples_UMTS900cov_num]
		,sum([samples_U900U2100cov_num]) [samples_U900U2100cov_num] --U900 y sólo una portadora de U2100
		,sum([samples_U2100_2Carriers_cov_num]) [samples_U2100_2Carriers_cov_num] --u2100 dos portadoras
		,sum([samples_U900U2100_2Carriers_cov_num]) [samples_U900U2100_2Carriers_cov_num] --U900 y dos portadoras
		,sum([samples_U2100_3Carriers_cov_num]) [samples_U2100_3Carriers_cov_num] --u2100 tres portadoras
		,sum([samples_U900U2100_3Carriers_cov_num]) [samples_U900U2100_3Carriers_cov_num] --U900 y tres portadoras

		,sum([UMTS2100_Carrier_only]) [samples_U2100_1Carriers_cov_num] --u2100 solo una portadora
		,sum([UMTS2100_F1]) [UMTS2100_F1]
		,sum([UMTS2100_F2]) [UMTS2100_F2]
		,sum([UMTS2100_F3]) [UMTS2100_F3]
		,sum([UMTS2100_P1]) [UMTS2100_P1]
		,sum([UMTS2100_P2]) [UMTS2100_P2]
		,sum([UMTS2100_P3]) [UMTS2100_P3]
		,sum([UMTS900_F1]) [UMTS900_F1]
		,sum([UMTS900_F2]) [UMTS900_F2]
		,sum([UMTS900_P1]) [UMTS900_P1]
		,sum([UMTS900_P2]) [UMTS900_P2]
		,sum([UMTS2100_F1_F2]) [UMTS2100_F1_F2]
		,sum([UMTS2100_F1_F3]) [UMTS2100_F1_F3]
		,sum([UMTS2100_F2_F3]) [UMTS2100_F2_F3]
		,sum([UMTS900_U2100_F1]) [UMTS900_U2100_F1]
		,sum([UMTS900_U2100_F2]) [UMTS900_U2100_F2]
		,sum([UMTS900_U2100_F3]) [UMTS900_U2100_F3]
		,sum([UMTS900_U2100_F1_F2]) [UMTS900_U2100_F1_F2]
		,sum([UMTS900_U2100_F1_F3]) [UMTS900_U2100_F1_F3]
		,sum([UMTS900_U2100_F2_F3]) [UMTS900_U2100_F2_F3]

		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG],0)))/10.0)*samplesAVG)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG)) as 'cobertura_AVG_3G_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG U2100],0)))/10.0)*samplesAVG_U2100)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_U2100)) as 'cobertura_AVG_U2100_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG U900],0)))/10.0)*samplesAVG_U900)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_U900)) as 'cobertura_AVG_U900_Num'
		,sum(samplesAVG) as 'samplesAVG_3G'
		,sum(samplesAVG_U2100) as 'samplesAVG_U2100'
		,sum(samplesAVG_U900) as 'samplesAVG_U900'

		,sum([Pollution]) as [Pollution]
		,sum([Pollution BS Curves]) as [Pollution BS Curves]
		,sum([Pollution BS Curves UMTS2100]) as [Pollution BS Curves UMTS2100]
		,sum([Pollution BS Curves UMTS900]) as [Pollution BS Curves UMTS900]		
		,sum([Pollution BS RSCP]) as [Pollution BS RSCP]
		,sum([Pollution BS RSCP UMTS2100]) as [Pollution BS RSCP UMTS2100]
		,sum([Pollution BS RSCP UMTS900]) as [Pollution BS RSCP UMTS900]
	
		,sum([UMTS_ProbCobInd]*UMTS_Samples_ProbCobInd) as UMTS_ProbCobInd
		,sum([UMTS2100_ProbCobInd]*UMTS2100_Samples_ProbCobInd) as UMTS2100_ProbCobInd
		,sum([UMTS2100_F1_ProbCobInd]*UMTS2100_F1_Samples_ProbCobInd) as UMTS2100_F1_ProbCobInd
		,sum([UMTS2100_F2_ProbCobInd]*UMTS2100_F2_Samples_ProbCobInd) as UMTS2100_F2_ProbCobInd
		,sum([UMTS2100_F3_ProbCobInd]*UMTS2100_F3_Samples_ProbCobInd) as UMTS2100_F3_ProbCobInd
		,sum([UMTS2100_P1_ProbCobInd]*UMTS2100_P1_Samples_ProbCobInd) as UMTS2100_P1_ProbCobInd
		,sum([UMTS2100_P2_ProbCobInd]*UMTS2100_P2_Samples_ProbCobInd) as UMTS2100_P2_ProbCobInd
		,sum([UMTS2100_P3_ProbCobInd]*UMTS2100_P3_Samples_ProbCobInd) as UMTS2100_P3_ProbCobInd	
		,sum([UMTS2100_F1_F2_ProbCobInd]*UMTS2100_F1_F2_Samples_ProbCobInd) as UMTS2100_F1_F2_ProbCobInd
		,sum([UMTS2100_F1_F3_ProbCobInd]*UMTS2100_F1_F3_Samples_ProbCobInd) as UMTS2100_F1_F3_ProbCobInd
		,sum([UMTS2100_F2_F3_ProbCobInd]*UMTS2100_F2_F3_Samples_ProbCobInd) as UMTS2100_F2_F3_ProbCobInd
		,sum([UMTS2100_F1_F2_F3_ProbCobInd]*UMTS2100_F1_F2_F3_Samples_ProbCobInd) as UMTS2100_F1_F2_F3_ProbCobInd
		,sum([UMTS900_ProbCobInd]*UMTS900_Samples_ProbCobInd) as UMTS900_ProbCobInd
		,sum([UMTS900_F1_ProbCobInd]*UMTS900_F1_Samples_ProbCobInd) as UMTS900_F1_ProbCobInd
		,sum([UMTS900_F2_ProbCobInd]*UMTS900_F2_Samples_ProbCobInd) as UMTS900_F2_ProbCobInd
		,sum([UMTS900_P1_ProbCobInd]*UMTS900_P1_Samples_ProbCobInd) as UMTS900_P1_ProbCobInd
		,sum([UMTS900_P2_ProbCobInd]*UMTS900_P2_Samples_ProbCobInd) as UMTS900_P2_ProbCobInd
		,sum([UMTS900_U2100_F1_ProbCobInd]*UMTS900_U2100_F1_Samples_ProbCobInd) as UMTS900_U2100_F1_ProbCobInd
		,sum([UMTS900_U2100_F2_ProbCobInd]*UMTS900_U2100_F2_Samples_ProbCobInd) as UMTS900_U2100_F2_ProbCobInd
		,sum([UMTS900_U2100_F3_ProbCobInd]*UMTS900_U2100_F3_Samples_ProbCobInd) as UMTS900_U2100_F3_ProbCobInd
		,sum([UMTS900_U2100_F1_F2_ProbCobInd]*UMTS900_U2100_F1_F2_Samples_ProbCobInd) as UMTS900_U2100_F1_F2_ProbCobInd
		,sum([UMTS900_U2100_F1_F3_ProbCobInd]*UMTS900_U2100_F1_F3_Samples_ProbCobInd) as UMTS900_U2100_F1_F3_ProbCobInd
		,sum([UMTS900_U2100_F2_F3_ProbCobInd]*UMTS900_U2100_F2_F3_Samples_ProbCobInd) as UMTS900_U2100_F2_F3_ProbCobInd
		,sum([UMTS900_U2100_F1_F2_F3_ProbCobInd]*UMTS900_U2100_F1_F2_F3_Samples_ProbCobInd) as UMTS900_U2100_F1_F2_F3_ProbCobInd
		,sum([UMTS_Samples_ProbCobInd]) as UMTS_Samples_ProbCobInd
		,sum([UMTS2100_Samples_ProbCobInd]) as UMTS2100_Samples_ProbCobInd
		,sum([UMTS2100_F1_Samples_ProbCobInd]) as UMTS2100_F1_Samples_ProbCobInd
		,sum([UMTS2100_F2_Samples_ProbCobInd]) as UMTS2100_F2_Samples_ProbCobInd
		,sum([UMTS2100_F3_Samples_ProbCobInd]) as UMTS2100_F3_Samples_ProbCobInd
		,sum([UMTS2100_P1_Samples_ProbCobInd]) as UMTS2100_P1_Samples_ProbCobInd
		,sum([UMTS2100_P2_Samples_ProbCobInd]) as UMTS2100_P2_Samples_ProbCobInd
		,sum([UMTS2100_P3_Samples_ProbCobInd]) as UMTS2100_P3_Samples_ProbCobInd
		,sum([UMTS2100_F1_F2_Samples_ProbCobInd]) as UMTS2100_F1_F2_Samples_ProbCobInd
		,sum([UMTS2100_F1_F3_Samples_ProbCobInd]) as UMTS2100_F1_F3_Samples_ProbCobInd
		,sum([UMTS2100_F2_F3_Samples_ProbCobInd]) as UMTS2100_F2_F3_Samples_ProbCobInd
		,sum([UMTS2100_F1_F2_F3_Samples_ProbCobInd]) as UMTS2100_F1_F2_F3_Samples_ProbCobInd
		,sum([UMTS900_Samples_ProbCobInd]) as UMTS900_Samples_ProbCobInd
		,sum([UMTS900_F1_Samples_ProbCobInd]) as UMTS900_F1_Samples_ProbCobInd
		,sum([UMTS900_F2_Samples_ProbCobInd]) as UMTS900_F2_Samples_ProbCobInd
		,sum([UMTS900_P1_Samples_ProbCobInd]) as UMTS900_P1_Samples_ProbCobInd
		,sum([UMTS900_P2_Samples_ProbCobInd]) as UMTS900_P2_Samples_ProbCobInd
		,sum([UMTS900_U2100_F1_Samples_ProbCobInd]) as UMTS900_U2100_F1_Samples_ProbCobInd
		,sum([UMTS900_U2100_F2_Samples_ProbCobInd]) as UMTS900_U2100_F2_Samples_ProbCobInd
		,sum([UMTS900_U2100_F3_Samples_ProbCobInd]) as UMTS900_U2100_F3_Samples_ProbCobInd
		,sum([UMTS900_U2100_F1_F2_Samples_ProbCobInd]) as UMTS900_U2100_F1_F2_Samples_ProbCobInd
		,sum([UMTS900_U2100_F1_F3_Samples_ProbCobInd]) as UMTS900_U2100_F1_F3_Samples_ProbCobInd
		,sum([UMTS900_U2100_F2_F3_Samples_ProbCobInd]) as UMTS900_U2100_F2_F3_Samples_ProbCobInd
		,sum([UMTS900_U2100_F1_F2_F3_Samples_ProbCobInd]) as UMTS900_U2100_F1_F2_F3_Samples_ProbCobInd

		,sum([UMTS2100_Carrier_only_ProbCobInd]*[UMTS2100_Carrier_only_Samples_ProbCobInd]) as [UMTS2100_Carrier_only_ProbCobInd]
		,sum([UMTS2100_Dual_Carrier_ProbCobInd]*[UMTS2100_Dual_Carrier_Samples_ProbCobInd]) as [UMTS2100_Dual_Carrier_ProbCobInd]
		,sum([UMTS900_U2100_Carrier_only_ProbCobInd]*[UMTS900_U2100_Carrier_only_Samples_ProbCobInd]) as [UMTS900_U2100_Carrier_only_ProbCobInd]
		,sum([UMTS900_U2100_Dual_Carrier_ProbCobInd]*[UMTS900_U2100_Dual_Carrier_Samples_ProbCobInd]) as [UMTS900_U2100_Dual_Carrier_ProbCobInd]
		,sum([UMTS2100_Carrier_only_Samples_ProbCobInd]) as [UMTS2100_Carrier_only_Samples_ProbCobInd]
		,sum([UMTS2100_Dual_Carrier_Samples_ProbCobInd]) as [UMTS2100_Dual_Carrier_Samples_ProbCobInd]
		,sum([UMTS900_U2100_Carrier_only_Samples_ProbCobInd]) as [UMTS900_U2100_Carrier_only_Samples_ProbCobInd]
		,sum([UMTS900_U2100_Dual_Carrier_Samples_ProbCobInd]) as [UMTS900_U2100_Dual_Carrier_Samples_ProbCobInd]
	
		-------------------------------------
		--,case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_VF end as Region_Road_VF
		--,case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_OSP end as Region_Road_OSP
		,cast(null as [nvarchar](255)) as calltype, cast(null as [nvarchar](255)) as ASideDevice, cast(null as [nvarchar](255)) as BSideDevice, cast(null as [nvarchar](255)) as SWVersion

	into _RI_Voice_cober3G
	from	[AGGRCoverage].[dbo].vlcc_cober3G_bands c, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(c.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,
		mnc, meas_round, Date_Reporting, Week_Reporting, entidad, c.report_type--,
		--case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_VF end,
		--case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_OSP end


	---------
	union all
	select 
		p.codigo_ine, 'Roads' vf_environment,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week,
	   'Road Cover' as meas_Tech, case when report_Type = 'ROAD' then entidad +'-RX' else entidad end as vf_entity, c.report_Type as report_Type, 'GRID' as aggr_type
		,sum([coverage_den]) as [coverage3G_den]
		,case when sum([UMTS_Samples_ProbCobInd]) is not null then sum([coverage_den]) end [coverage3G_den_ProbCob]		-- se usara este por los nulos de los AVEs
		,sum([samples_3Gcov_num]) [samples_3Gcov_num]
		,sum([samples_U2100cov_num]) [samples_U2100cov_num]
		,sum([samples_UMTS900cov_num]) [samples_UMTS900cov_num]
		,sum([samples_U900U2100cov_num]) [samples_U900U2100cov_num]
		,sum([samples_U2100_2Carriers_cov_num]) [samples_U2100_2Carriers_cov_num]
		,sum([samples_U900U2100_2Carriers_cov_num]) [samples_U900U2100_2Carriers_cov_num]
		,sum([samples_U2100_3Carriers_cov_num]) [samples_U2100_3Carriers_cov_num]
		,sum([samples_U900U2100_3Carriers_cov_num]) [samples_U900U2100_3Carriers_cov_num]

		,sum([UMTS2100_Carrier_only]) [samples_U2100_1Carriers_cov_num] --u2100 solo una portadora
		,sum([UMTS2100_F1]) [UMTS2100_F1]
		,sum([UMTS2100_F2]) [UMTS2100_F2]
		,sum([UMTS2100_F3]) [UMTS2100_F3]
		,sum([UMTS2100_P1]) [UMTS2100_P1]
		,sum([UMTS2100_P2]) [UMTS2100_P2]
		,sum([UMTS2100_P3]) [UMTS2100_P3]
		,sum([UMTS900_F1]) [UMTS900_F1]
		,sum([UMTS900_F2]) [UMTS900_F2]
		,sum([UMTS900_P1]) [UMTS900_P1]
		,sum([UMTS900_P2]) [UMTS900_P2]
		,sum([UMTS2100_F1_F2]) [UMTS2100_F1_F2]
		,sum([UMTS2100_F1_F3]) [UMTS2100_F1_F3]
		,sum([UMTS2100_F2_F3]) [UMTS2100_F2_F3]
		,sum([UMTS900_U2100_F1]) [UMTS900_U2100_F1]
		,sum([UMTS900_U2100_F2]) [UMTS900_U2100_F2]
		,sum([UMTS900_U2100_F3]) [UMTS900_U2100_F3]
		,sum([UMTS900_U2100_F1_F2]) [UMTS900_U2100_F1_F2]
		,sum([UMTS900_U2100_F1_F3]) [UMTS900_U2100_F1_F3]
		,sum([UMTS900_U2100_F2_F3]) [UMTS900_U2100_F2_F3]
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG],0)))/10.0)*samplesAVG)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG)) as 'cobertura_AVG_3G_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG U2100],0)))/10.0)*samplesAVG_U2100)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_U2100)) as 'cobertura_AVG_U2100_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG U900],0)))/10.0)*samplesAVG_U900)+sum(POWER(convert(float,10.0),(convert(float,-140))/10.0)*([coverage_den]-samplesAVG_U900)) as 'cobertura_AVG_U900_Num'
		,sum(samplesAVG) as 'samplesAVG_3G'
		,sum(samplesAVG_U2100) as 'samplesAVG_U2100'
		,sum(samplesAVG_U900) as 'samplesAVG_U900'

		,sum([Pollution]) as [Pollution]
		,sum([Pollution BS Curves]) as [Pollution BS Curves]
		,sum([Pollution BS Curves UMTS2100]) as [Pollution BS Curves UMTS2100]
		,sum([Pollution BS Curves UMTS900]) as [Pollution BS Curves UMTS900]		
		,sum([Pollution BS RSCP]) as [Pollution BS RSCP]
		,sum([Pollution BS RSCP UMTS2100]) as [Pollution BS RSCP UMTS2100]
		,sum([Pollution BS RSCP UMTS900]) as [Pollution BS RSCP UMTS900]
	
		,sum([UMTS_ProbCobInd]*UMTS_Samples_ProbCobInd) as UMTS_ProbCobInd
		,sum([UMTS2100_ProbCobInd]*UMTS2100_Samples_ProbCobInd) as UMTS2100_ProbCobInd
		,sum([UMTS2100_F1_ProbCobInd]*UMTS2100_F1_Samples_ProbCobInd) as UMTS2100_F1_ProbCobInd
		,sum([UMTS2100_F2_ProbCobInd]*UMTS2100_F2_Samples_ProbCobInd) as UMTS2100_F2_ProbCobInd
		,sum([UMTS2100_F3_ProbCobInd]*UMTS2100_F3_Samples_ProbCobInd) as UMTS2100_F3_ProbCobInd
		,sum([UMTS2100_P1_ProbCobInd]*UMTS2100_P1_Samples_ProbCobInd) as UMTS2100_P1_ProbCobInd
		,sum([UMTS2100_P2_ProbCobInd]*UMTS2100_P2_Samples_ProbCobInd) as UMTS2100_P2_ProbCobInd
		,sum([UMTS2100_P3_ProbCobInd]*UMTS2100_P3_Samples_ProbCobInd) as UMTS2100_P3_ProbCobInd
		,sum([UMTS2100_F1_F2_ProbCobInd]*UMTS2100_F1_F2_Samples_ProbCobInd) as UMTS2100_F1_F2_ProbCobInd
		,sum([UMTS2100_F1_F3_ProbCobInd]*UMTS2100_F1_F3_Samples_ProbCobInd) as UMTS2100_F1_F3_ProbCobInd
		,sum([UMTS2100_F2_F3_ProbCobInd]*UMTS2100_F2_F3_Samples_ProbCobInd) as UMTS2100_F2_F3_ProbCobInd
		,sum([UMTS2100_F1_F2_F3_ProbCobInd]*UMTS2100_F1_F2_F3_Samples_ProbCobInd) as UMTS2100_F1_F2_F3_ProbCobInd
		,sum([UMTS900_ProbCobInd]*UMTS900_Samples_ProbCobInd) as UMTS900_ProbCobInd
		,sum([UMTS900_F1_ProbCobInd]*UMTS900_F1_Samples_ProbCobInd) as UMTS900_F1_ProbCobInd
		,sum([UMTS900_F2_ProbCobInd]*UMTS900_F2_Samples_ProbCobInd) as UMTS900_F2_ProbCobInd
		,sum([UMTS900_P1_Samples_ProbCobInd]) as UMTS900_P1_Samples_ProbCobInd
		,sum([UMTS900_P2_Samples_ProbCobInd]) as UMTS900_P2_Samples_ProbCobInd
		,sum([UMTS900_U2100_F1_ProbCobInd]*UMTS900_U2100_F1_Samples_ProbCobInd) as UMTS900_U2100_F1_ProbCobInd
		,sum([UMTS900_U2100_F2_ProbCobInd]*UMTS900_U2100_F2_Samples_ProbCobInd) as UMTS900_U2100_F2_ProbCobInd
		,sum([UMTS900_U2100_F3_ProbCobInd]*UMTS900_U2100_F3_Samples_ProbCobInd) as UMTS900_U2100_F3_ProbCobInd
		,sum([UMTS900_U2100_F1_F2_ProbCobInd]*UMTS900_U2100_F1_F2_Samples_ProbCobInd) as UMTS900_U2100_F1_F2_ProbCobInd
		,sum([UMTS900_U2100_F1_F3_ProbCobInd]*UMTS900_U2100_F1_F3_Samples_ProbCobInd) as UMTS900_U2100_F1_F3_ProbCobInd
		,sum([UMTS900_U2100_F2_F3_ProbCobInd]*UMTS900_U2100_F2_F3_Samples_ProbCobInd) as UMTS900_U2100_F2_F3_ProbCobInd
		,sum([UMTS900_U2100_F1_F2_F3_ProbCobInd]*UMTS900_U2100_F1_F2_F3_Samples_ProbCobInd) as UMTS900_U2100_F1_F2_F3_ProbCobInd
		,sum([UMTS_Samples_ProbCobInd]) as UMTS_Samples_ProbCobInd
		,sum([UMTS2100_Samples_ProbCobInd]) as UMTS2100_Samples_ProbCobInd
		,sum([UMTS2100_F1_Samples_ProbCobInd]) as UMTS2100_F1_Samples_ProbCobInd
		,sum([UMTS2100_F2_Samples_ProbCobInd]) as UMTS2100_F2_Samples_ProbCobInd
		,sum([UMTS2100_F3_Samples_ProbCobInd]) as UMTS2100_F3_Samples_ProbCobInd
		,sum([UMTS2100_P1_Samples_ProbCobInd]) as UMTS2100_P1_Samples_ProbCobInd
		,sum([UMTS2100_P2_Samples_ProbCobInd]) as UMTS2100_P2_Samples_ProbCobInd
		,sum([UMTS2100_P3_Samples_ProbCobInd]) as UMTS2100_P3_Samples_ProbCobInd
		,sum([UMTS2100_F1_F2_Samples_ProbCobInd]) as UMTS2100_F1_F2_Samples_ProbCobInd
		,sum([UMTS2100_F1_F3_Samples_ProbCobInd]) as UMTS2100_F1_F3_Samples_ProbCobInd
		,sum([UMTS2100_F2_F3_Samples_ProbCobInd]) as UMTS2100_F2_F3_Samples_ProbCobInd
		,sum([UMTS2100_F1_F2_F3_Samples_ProbCobInd]) as UMTS2100_F1_F2_F3_Samples_ProbCobInd
		,sum([UMTS900_Samples_ProbCobInd]) as UMTS900_Samples_ProbCobInd
		,sum([UMTS900_F1_Samples_ProbCobInd]) as UMTS900_F1_Samples_ProbCobInd
		,sum([UMTS900_F2_Samples_ProbCobInd]) as UMTS900_F2_Samples_ProbCobInd
		,sum([UMTS900_P1_Samples_ProbCobInd]) as UMTS900_P1_Samples_ProbCobInd
		,sum([UMTS900_P2_Samples_ProbCobInd]) as UMTS900_P2_Samples_ProbCobInd
		,sum([UMTS900_U2100_F1_Samples_ProbCobInd]) as UMTS900_U2100_F1_Samples_ProbCobInd
		,sum([UMTS900_U2100_F2_Samples_ProbCobInd]) as UMTS900_U2100_F2_Samples_ProbCobInd
		,sum([UMTS900_U2100_F3_Samples_ProbCobInd]) as UMTS900_U2100_F3_Samples_ProbCobInd		
		,sum([UMTS900_U2100_F1_F2_Samples_ProbCobInd]) as UMTS900_U2100_F1_F2_Samples_ProbCobInd
		,sum([UMTS900_U2100_F1_F3_Samples_ProbCobInd]) as UMTS900_U2100_F1_F3_Samples_ProbCobInd
		,sum([UMTS900_U2100_F2_F3_Samples_ProbCobInd]) as UMTS900_U2100_F2_F3_Samples_ProbCobInd
		,sum([UMTS900_U2100_F1_F2_F3_Samples_ProbCobInd]) as UMTS900_U2100_F1_F2_F3_Samples_ProbCobInd

		,sum([UMTS2100_Carrier_only_ProbCobInd]*[UMTS2100_Carrier_only_Samples_ProbCobInd]) as [UMTS2100_Carrier_only_ProbCobInd]
		,sum([UMTS2100_Dual_Carrier_ProbCobInd]*[UMTS2100_Dual_Carrier_Samples_ProbCobInd]) as [UMTS2100_Dual_Carrier_ProbCobInd]
		,sum([UMTS900_U2100_Carrier_only_ProbCobInd]*[UMTS900_U2100_Carrier_only_Samples_ProbCobInd]) as [UMTS900_U2100_Carrier_only_ProbCobInd]
		,sum([UMTS900_U2100_Dual_Carrier_ProbCobInd]*[UMTS900_U2100_Dual_Carrier_Samples_ProbCobInd]) as [UMTS900_U2100_Dual_Carrier_ProbCobInd]
		,sum([UMTS2100_Carrier_only_Samples_ProbCobInd]) as [UMTS2100_Carrier_only_Samples_ProbCobInd]
		,sum([UMTS2100_Dual_Carrier_Samples_ProbCobInd]) as [UMTS2100_Dual_Carrier_Samples_ProbCobInd]
		,sum([UMTS900_U2100_Carrier_only_Samples_ProbCobInd]) as [UMTS900_U2100_Carrier_only_Samples_ProbCobInd]
		,sum([UMTS900_U2100_Dual_Carrier_Samples_ProbCobInd]) as [UMTS900_U2100_Dual_Carrier_Samples_ProbCobInd]

		-------------------------------------
		--,c.Region_VF as Region_Road_VF, c.Region_OSP as Region_Road_OSP
		,cast(null as [nvarchar](255)) as calltype, cast(null as [nvarchar](255)) as ASideDevice, cast(null as [nvarchar](255)) as BSideDevice, cast(null as [nvarchar](255)) as SWVersion

	from	[AGGRCoverage_ROAD].[dbo].vlcc_cober3G_bands c, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(c.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, mnc,meas_round,Date_Reporting,Week_Reporting,entidad, c.report_type--, c.Region_VF, c.Region_OSP

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 6. COVERAGE 3G y Road 3G', getdate()


	------------------------------------------------------------------------------
	-- 7. COVERAGE 2G y Road 2G
	------------------------------------------------------------------------------
	print '7. COVERAGE 2G y Road 2G'
	-----------
	select 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end as vf_environment ,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week,
	   'Cover' as meas_Tech,  entidad as vf_entity, c.report_Type as report_Type, 'GRID' as aggr_type
		,sum([coverage_den]) as [coverage2G_den]
		,case when sum([2G_Samples_ProbCobInd]) is not null then sum([coverage_den]) end [coverage2G_den_ProbCob]		-- se usara este por los nulos de los AVEs
		,sum([samples_2Gcov_num]) [samples_2Gcov_num]
		,sum([samples_GSMcov_num]) as [samples_GSMcov_num]
		, sum(samples_DCScov_num) as samples_DCScov_num
		,sum(samples_GSMDCScov_num) as samples_GSMDCScov_num
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG],0)))/10.0)*samplesAVG)+sum(POWER(convert(float,10.0),(convert(float,-110))/10.0)*([coverage_den]-samplesAVG)) as 'cobertura_AVG_2G_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG GSM],0)))/10.0)*samplesAVG_GSM)+sum(POWER(convert(float,10.0),(convert(float,-110))/10.0)*([coverage_den]-samplesAVG_GSM)) as 'cobertura_AVG_GSM_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG DCS],0)))/10.0)*samplesAVG_DCS)+sum(POWER(convert(float,10.0),(convert(float,-110))/10.0)*([coverage_den]-samplesAVG_DCS)) as 'cobertura_AVG_DCS_Num'
		,sum(samplesAVG) as 'samplesAVG_2G'
		,sum(samplesAVG_GSM) as 'samplesAVG_GSM'
		,sum(samplesAVG_DCS) as 'samplesAVG_DCS'
		,sum([2G_ProbCobInd]*[2G_Samples_ProbCobInd]) as [2G_ProbCobInd]
		,sum(GSM_ProbCobInd*GSM_Samples_ProbCobInd) as GSM_ProbCobInd
		,sum(DCS_ProbCobInd*DCS_Samples_ProbCobInd) as DCS_ProbCobInd
		,sum(GSM_DCS_ProbCobInd*GSM_DCS_Samples_ProbCobInd) as GSM_DCS_ProbCobInd
		,sum([2G_Samples_ProbCobInd]) as [2G_Samples_ProbCobInd]
		,sum(GSM_Samples_ProbCobInd) as GSM_Samples_ProbCobInd
		,sum(DCS_Samples_ProbCobInd) as DCS_Samples_ProbCobInd
		,sum(GSM_DCS_Samples_ProbCobInd) as GSM_DCS_Samples_ProbCobInd

		-------------------------------------
		--,case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_VF end as Region_Road_VF
		--,case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_OSP end as Region_Road_OSP
		,cast(null as [nvarchar](255)) as calltype, cast(null as [nvarchar](255)) as ASideDevice, cast(null as [nvarchar](255)) as BSideDevice, cast(null as [nvarchar](255)) as SWVersion

	into _RI_Voice_cober2G
	from	[AGGRCoverage].[dbo].vlcc_cober2G_bands c, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(c.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, case when entidad like 'AVE-%' or entidad like 'MAD-___-R[0-9]%' then  'AVE' else p.vf_environment end,
		mnc,meas_round,Date_Reporting,Week_Reporting,entidad, c.report_type--,
		--case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_VF end,
		--case when c.entidad like 'AVE-%' or c.entidad like 'MAD-___-R[0-9]%' then  'AVE' else c.Region_OSP end

	---------
	union all 
	select 
		p.codigo_ine, 'Roads' vf_environment,mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week,
		'Road Cover' as meas_Tech,  case when report_Type = 'ROAD' then entidad +'-RX' else entidad end as vf_entity, c.report_Type as report_Type, 'GRID' as aggr_type
		,sum([coverage_den]) as [coverage2G_den]
		,case when sum([2G_Samples_ProbCobInd]) is not null then sum([coverage_den]) end [coverage2G_den_ProbCob]	-- se usara este por los nulos de los AVEs
		,sum([samples_2Gcov_num]) [samples_2Gcov_num]
		,sum([samples_GSMcov_num]) as [samples_GSMcov_num]
		, sum(samples_DCScov_num) as samples_DCScov_num
		,sum(samples_GSMDCScov_num) as samples_GSMDCScov_num
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG],0)))/10.0)*samplesAVG)+sum(POWER(convert(float,10.0),(convert(float,-110))/10.0)*([coverage_den]-samplesAVG)) as 'cobertura_AVG_2G_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG GSM],0)))/10.0)*samplesAVG_GSM)+sum(POWER(convert(float,10.0),(convert(float,-110))/10.0)*([coverage_den]-samplesAVG_GSM)) as 'cobertura_AVG_GSM_Num'
		,sum(POWER(convert(float,10.0),(convert(float,isnull([cobertura AVG DCS],0)))/10.0)*samplesAVG_DCS)+sum(POWER(convert(float,10.0),(convert(float,-110))/10.0)*([coverage_den]-samplesAVG_DCS)) as 'cobertura_AVG_DCS_Num'
		,sum(samplesAVG) as 'samplesAVG_2G'
		,sum(samplesAVG_GSM) as 'samplesAVG_GSM'
		,sum(samplesAVG_DCS) as 'samplesAVG_DCS'
		,sum([2G_ProbCobInd]*[2G_Samples_ProbCobInd]) as [2G_ProbCobInd]
		,sum(GSM_ProbCobInd*GSM_Samples_ProbCobInd) as GSM_ProbCobInd
		,sum(DCS_ProbCobInd*DCS_Samples_ProbCobInd) as DCS_ProbCobInd
		,sum(GSM_DCS_ProbCobInd*GSM_DCS_Samples_ProbCobInd) as GSM_DCS_ProbCobInd
		,sum([2G_Samples_ProbCobInd]) as [2G_Samples_ProbCobInd]
		,sum(GSM_Samples_ProbCobInd) as GSM_Samples_ProbCobInd
		,sum(DCS_Samples_ProbCobInd) as DCS_Samples_ProbCobInd
		,sum(GSM_DCS_Samples_ProbCobInd) as GSM_DCS_Samples_ProbCobInd

		-------------------------------------
		--,c.Region_VF as Region_Road_VF, c.Region_OSP as Region_Road_OSP
		,cast(null as [nvarchar](255)) as calltype, cast(null as [nvarchar](255)) as ASideDevice, cast(null as [nvarchar](255)) as BSideDevice, cast(null as [nvarchar](255)) as SWVersion

	from	[AGGRCoverage_ROAD].[dbo].vlcc_cober2G_bands c, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(c.parcel,'0.00000 Long, 0.00000 Lat')
	group by 
		p.codigo_ine, mnc,meas_round,Date_Reporting,Week_Reporting,entidad, c.report_type--, c.Region_VF, c.Region_OSP

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 7. COVERAGE 2G y Road 2G', getdate()


	--------------------------------------------------------------------------------------
	-- UPDATE parcelas sin info - no se pueden dejar con codigoINE=99999 porque eso es de Indoor
	--------------------------------------------------------------------------------------
	update _RI_Voice_c set codigo_ine='' where codigo_ine=99999 and vf_environment<>'Indoor'
	update _RI_Voice_m set codigo_ine='' where codigo_ine=99999 and vf_environment<>'Indoor'
	update _RI_Voice_cst set codigo_ine='' where codigo_ine=99999 and vf_environment<>'Indoor'
	update _RI_Voice_cst_csfb set codigo_ine='' where codigo_ine=99999 and vf_environment<>'Indoor'

	update _RI_Voice_cober4G set codigo_ine='' where codigo_ine=99999 and vf_environment<>'Indoor'
	update _RI_Voice_cober2G set codigo_ine='' where codigo_ine=99999 and vf_environment<>'Indoor'
	update _RI_Voice_cober3G set codigo_ine='' where codigo_ine=99999 and vf_environment<>'Indoor'


	------------------------------------------------------------------------------
	-- 8. Coverage poblacional entidad (sin calculo por entorno) 4G:
	------------------------------------------------------------------------------ 
	print '8. Coverage poblacional entidad (sin calculo por entorno) 4G'
	-----------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober4G_Pob_Entidad'
	select 
		p.codigo_ine, mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week,
	   'Cover' as meas_Tech,  entidad as vf_entity, c.report_Type as report_Type, 'GRID' as aggr_type
		,sum([coverage_den]) as [coverage4G_den]
		,sum(LTE_ProbCobInd*LTE_Samples_ProbCobInd) as LTE_ProbCobInd		
		,sum(LTE_Samples_ProbCobInd) as LTE_Samples_ProbCobInd

	into _RI_Voice_cober4G_Pob_Entidad
	from	[AGGRCoverage].[dbo].vlcc_cober4G_bands c, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(c.parcel,'0.00000 Long, 0.00000 Lat')
		   and entidad not like 'AVE-%' and entidad not like 'MAD-___-R[0-9]%' --No AVEs
	group by 
		p.codigo_ine,mnc,meas_round,Date_Reporting,Week_Reporting,entidad, c.report_type

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 8. Coverage poblacional entidad (sin calculo por entorno) 4G', getdate()


	------------------------------------------------------------------------------
	-- 9. Coverage poblacional entidad (sin calculo por entorno) 3G:
	------------------------------------------------------------------------------ 
	print '9. Coverage poblacional entidad (sin calculo por entorno) 3G'
	-----------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober3G_Pob_Entidad'
	select 
		p.codigo_ine, mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week,
	   'Cover' as meas_Tech,  entidad as vf_entity, c.report_Type as report_Type, 'GRID' as aggr_type
		,sum([coverage_den]) as [coverage3G_den]
		,sum([UMTS_ProbCobInd]*UMTS_Samples_ProbCobInd) as UMTS_ProbCobInd		
		,sum([UMTS_Samples_ProbCobInd]) as UMTS_Samples_ProbCobInd	
			
	into _RI_Voice_cober3G_Pob_Entidad
	from	[AGGRCoverage].[dbo].vlcc_cober3G_bands c, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(c.parcel,'0.00000 Long, 0.00000 Lat')
		   and entidad not like 'AVE-%' and entidad not like 'MAD-___-R[0-9]%' --No AVEs
	group by 
		p.codigo_ine, mnc,meas_round,Date_Reporting,Week_Reporting,entidad, c.report_type

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 9. Coverage poblacional entidad (sin calculo por entorno) 3G', getdate()


	------------------------------------------------------------------------------
	--- 10. Coverage poblacional entidad (sin calculo por entorno) 2G:
	------------------------------------------------------------------------------ 
	print '10. Coverage poblacional entidad (sin calculo por entorno) 2G'
	-----------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober2G_Pob_Entidad'
	select 
		p.codigo_ine, mnc,meas_round,Date_Reporting as meas_date,Week_Reporting as meas_week,
	   'Cover' as meas_Tech,  entidad as vf_entity, c.report_Type as report_Type, 'GRID' as aggr_type
		,sum([coverage_den]) as [coverage2G_den]
		,sum([2G_ProbCobInd]*[2G_Samples_ProbCobInd]) as [2G_ProbCobInd]
		,sum([2G_Samples_ProbCobInd]) as [2G_Samples_ProbCobInd]

	into _RI_Voice_cober2G_Pob_Entidad
	from	[AGGRCoverage].[dbo].vlcc_cober2G_bands c, [AGRIDS].[dbo].vlcc_parcelas_osp p
	where p.parcela=isnull(c.parcel,'0.00000 Long, 0.00000 Lat')
		   and entidad not like 'AVE-%' and entidad not like 'MAD-___-R[0-9]%' --No AVEs
	group by 
		p.codigo_ine, mnc,meas_round,Date_Reporting,Week_Reporting,entidad, c.report_type

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 10. Coverage poblacional entidad (sin calculo por entorno) 2G', getdate()


	------------------------------------------------------------------------------
	-- 11. Base Structure		- modificar esta estructura implica modificar en el punto 16 - cuenta de entornos
	------------------------------------------------------------------------------
	print '11. Base Structure'
	-----------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base1'
	select codigo_ine, vf_environment, mnc, meas_round ,meas_date, meas_week, meas_Tech, VF_entity, Report_Type, Aggr_Type, calltype, ASideDevice, BSideDevice, SWVersion		--, Region_Road_VF, Region_Road_OSP
	into _RI_Voice_base1
	from
	(
		select  codigo_ine,vf_environment,mnc,meas_round,meas_date,meas_week,meas_Tech,VF_entity,Report_Type,Aggr_Type, calltype, ASideDevice, BSideDevice, SWVersion from _RI_Voice_c
		union all 
		select  codigo_ine,vf_environment,mnc,meas_round,meas_date,meas_week,meas_Tech,VF_entity,Report_Type,Aggr_Type, calltype, ASideDevice, BSideDevice, SWVersion from _RI_Voice_m
		union all 
		select  codigo_ine,vf_environment,mnc,meas_round,meas_date,meas_week,meas_Tech,VF_entity,Report_Type,Aggr_Type, calltype, ASideDevice, BSideDevice, SWVersion from _RI_Voice_cst
		union all 
		select  codigo_ine,vf_environment,mnc,meas_round,meas_date,meas_week,meas_Tech,VF_entity,Report_Type,Aggr_Type, calltype, ASideDevice, BSideDevice, SWVersion from _RI_Voice_cst_csfb	
		union all 
		select  codigo_ine,vf_environment,mnc,meas_round,meas_date,meas_week,meas_Tech,VF_entity,Report_Type,Aggr_Type, calltype, ASideDevice, BSideDevice, SWVersion from _RI_Voice_cober4G
		union all 
		select  codigo_ine,vf_environment,mnc,meas_round,meas_date,meas_week,meas_Tech,VF_entity,Report_Type,Aggr_Type, calltype, ASideDevice, BSideDevice, SWVersion from _RI_Voice_cober3G
		union all 
		select  codigo_ine,vf_environment,mnc,meas_round,meas_date,meas_week,meas_Tech,VF_entity,Report_Type,Aggr_Type, calltype, ASideDevice, BSideDevice, SWVersion from _RI_Voice_cober2G
	) t
	group by codigo_ine, vf_environment, mnc, meas_round ,meas_date, meas_week, meas_Tech, VF_entity, Report_Type, Aggr_Type, calltype, ASideDevice, BSideDevice, SWVersion

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 11. Base Structure', getdate()


	------------------------------------------------------------------------------
	-- 12. Calculo de los indice de VODAFONE Y ORANGE:		** NUEVO- incluido VODAFONE
	------------------------------------------------------------------------------
	print '12. Calculo de los indice de VODAFONE Y ORANGE'
	-----------
	
	/*Paso 1: Creamos una tabla linkando la tabla base que hemos ido creando con la tabla que nos indica si las medidas están Completadas o no
	con una Subquery con la que añadiremos un contador que tendrá el valor 1 ó 2 dependiendo del tipo de reporte (VDF o MUN) por entidad, así podremos
	saber si una entidad ha sido sólo medida por VDF, MUN o por ambas*/
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base_x'
	select q.*,c.completed_OSP, d.cont_report_type
	into _RI_Voice_base_x 
	from _RI_Voice_base1 q 
		left join addedValue.[dbo].[lcc_entities_completed_Report] c on (q.vf_entity=c.entity_name and q.meas_round=c.meas_round)
		left join (
				Select u.vf_entity, mnc, u.meas_tech,
				count(distinct(report_type)) as 'cont_report_type'
				from _RI_Voice_base1 u	    
				group by vf_entity,mnc, u.meas_tech
				) d on (q.vf_entity = d.vf_entity and q.mnc=d.mnc and q.meas_tech=d.meas_tech)


	/*Paso 2: linkamos la tabla creada en el punto anterior y la linkamos con una Subquery que crea un id para marcar a 1 por tipo de reporte y entidad 
	Completada. Sumamos estos 1s y al final tendremos un índica (id_comp) que podrá valer 0 sino hay ninguna medida completada, 1 si sólo hay una medida completada
	2 si hay dos medidas completadas*/

	/*cont_report_type = contador de report_type distintos para una misma entidad		-- count(distinct(report_type))
	  id_comp = índice de completadas. Nos dice cuántas veces está completada una entidad*/
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base'
	Select 
		q.*, comp.id_comp,
		Case	
			/*Si sólo hay un tipo de medida (VDF O MUN), me da igual el tipo y la marco como 1 siempre que esté completada*/
			when (q.cont_report_type=1 and q.completed_OSP = 'Y') then 1     
		
			/*Si mi índice de comprobación es 2 y mi contador por reporte es 2, es que hay medidas VDF y MUN ambas completadas, por lo que me quedo con la medida por MUN*/
			when (q.cont_report_type=2 and (q.report_type = 'MUN' or q.report_type = 'OSP') and comp.id_comp=2 and q.completed_OSP = 'Y') then 1   
		
			/*Si mi contador por reportes es 2 (tengo medida por VDF y MUN) y mi contador por Completado (id_comp) es 1 es que uno de las dos medidas está completada, nos quedamos con esa medida*/
			when (q.cont_report_type=2  and comp.id_comp=1 and q.completed_OSP = 'Y') then 1   
		else 0 end as id_osp,
		----------------------------------
		-- En este id me da igual que este completada la medida o no:
		Case	
			/*Si sólo hay un tipo de medida (VDF O MUN), me da igual el tipo y la marco como 1, me da igual que esté completada o no*/
			when (q.cont_report_type=1) then 1     
		
			/*Si mi índice de comprobación es 2, es que tengo medida por VDF y MUN), por lo que me quedo con la medida por MUN*/
			when (q.cont_report_type=2 and (q.report_type = 'MUN' or q.report_type = 'OSP')) then 1   
		else 0 end as id_osp_noComp,			 		 

		----------------------------------	

		Case when (q.report_type = 'VDF') then 1 else 0 end as id_vdf    /*Nos quedamos con las medidas VDF*/

	into _RI_Voice_base
	from _RI_Voice_base_x q
			left join (select vf_entity,meas_tech,meas_date, sum(id) as id_comp
						from(
							Select vf_entity,report_type,meas_tech,meas_date,
									Case when completed_OSP='Y' then 1 else 0 end as 'id'
							from _RI_Voice_base_x
							group by vf_entity, meas_tech,report_type,completed_OSP,meas_date
							) a
						group by vf_entity,meas_tech,meas_date
						) comp on (q.vf_entity=comp.vf_entity and q.meas_tech=comp.meas_tech and q.meas_date=comp.meas_date)

	-- select * from _RI_Voice_base where vf_entity like '%A-40%'

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 12. Calculo de los indice de VODAFONE Y ORANGE', getdate()


	------------------------------------------------------------------------------
	-- 13. Base Cober Pob Entidad
	------------------------------------------------------------------------------
	print '13. Base Cober Pob Entidad'
	-----------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base1_Pob_Entidad'
	select codigo_ine, mnc, meas_round, meas_date, meas_week, meas_Tech, VF_entity, Report_Type, Aggr_Type
	into _RI_Voice_base1_Pob_Entidad
	from
	(
		select  codigo_ine,mnc,meas_round,meas_date,meas_week,meas_Tech,VF_entity,Report_Type,Aggr_Type from _RI_Voice_cober4G_Pob_Entidad
		union all 
		select  codigo_ine,mnc,meas_round,meas_date,meas_week,meas_Tech,VF_entity,Report_Type,Aggr_Type from _RI_Voice_cober3G_Pob_Entidad
		union all 
		select  codigo_ine,mnc,meas_round,meas_date,meas_week,meas_Tech,VF_entity,Report_Type,Aggr_Type from _RI_Voice_cober2G_Pob_Entidad
	) t
	group by codigo_ine,mnc,meas_round,meas_date,meas_week,meas_Tech,VF_entity,Report_Type,Aggr_Type

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 13. Base Cober Pob Entidad', getdate()


	------------------------------------------------------------------------------
	-- 14. Registro base:	mnc, meas_round, meas_date, meas_week, meas_tech, vf_entity
	-- Se presupone que date_reporting y week_reporting es igual para cualquier tipo de reporte 
	--	(al acabar de agregar se debe lanzar [sp_lcc_update_Dates_Reporting_Aggr_D16])
	------------------------------------------------------------------------------
	print '14. Registro base'
	-----------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_i_Pob_Entidad'
	select *, row_number() over 
					  (partition by mnc, meas_round, meas_tech, vf_entity
					   order by report_type asc) as id
	into _RI_Voice_i_Pob_Entidad
	from _RI_Voice_base1_Pob_Entidad

	---------------------------------------
	--Nos quedamos por registro base por el primer report_type existente (MUN ó OSP ó VDF)
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base_report_Pob_Entidad'
	select * 
	into _RI_Voice_base_report_Pob_Entidad
	from _RI_Voice_i_Pob_Entidad 
	where id=1

	---------------------------------------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base_Pob_Entidad'
	select b.* 
	into _RI_Voice_base_Pob_Entidad
	from _RI_Voice_base1_Pob_Entidad b
		inner join _RI_Voice_base_report_Pob_Entidad br
		on (b.mnc=br.mnc and isnull(b.meas_round,0)=isnull(br.meas_round,0)
			and b.meas_date=br.meas_date and b.meas_week=br.meas_week 
			and b.meas_Tech=br.meas_Tech and b.vf_entity=br.vf_entity
			and b.Report_Type=br.Report_Type)

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 14. Registro base', getdate()


	------------------------------------------------------------------------------
	-- El resultado se pone en 2 veces, para añadir el codigo ine en función de la entidad
	--    y evitar malentendidos en codigos ine colindantes en parcelas
	------------------------------------------------------------------------------
	-- 15. Primer union de todas las tablas temporales -> select * from _RI_Voice_result1:
	------------------------------------------------------------------------------
	print '15. Primer union de todas las tablas temporales -> _RI_Voice_result1'
	-----------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result1'
	select 
		b.codigo_ine,

		-- Se le añade la PROVINCIA y CCAA solo a carreteras y AVES, ya que en entidades puede meter desglose extra en los casos en los que se salga (carreteras sobre todo)
		case when b.vf_environment ='ave' or (b.vf_environment = 'roads' and b.meas_Tech like '%Road%') then p.Provincia else NULL end as Provincia,
		case when b.vf_environment ='ave' or (b.vf_environment = 'roads' and b.meas_Tech like '%Road%') then p.CCAA else NULL end as CCAA,

		b.vf_environment as environment,
		case b.mnc 
			when'01' then 'Vodafone' 
			when '03' then 'Orange' 
			when '07' then 'Movistar' 
			when '04' then 'Yoigo' 
		end as operator
		,b.mnc, b.meas_round, b.meas_date, b.meas_week, b.meas_Tech, b.VF_entity as entity
		,b.Report_Type, b.id_osp, b.id_vdf	
		,b.id_osp_noComp
		,b.callType

		-- Calls:
		,c.[MOC_Calls]
		,c.[MTC_Calls]
		,c.[MOC_Blocks]
		,c.[MTC_Blocks]
		,c.[MOC_Drops]
		,c.[MTC_Drops]
		,c.[Calls]
		,c.[Blocks]
		,c.[Drops]
		,c.[CR_Affected_Calls]
		,c.Call_duration_3G
		,c.Call_duration_2G
		,c.Call_duration_tech_samples
		,c.CSFB_to_GSM_samples
		,c.CSFB_to_UMTS_samples
		,c.CSFB_samples
		,c.AMR_FR_samples, c.AMR_HR_samples, c.AMR_WB_samples, c.FR_samples, c.EFR_samples, c.HR_samples, c.codec_samples 
		,c.[NUMBERS OF CALLS Non Sustainability (NB)]
		,c.[NUMBERS OF CALLS Non Sustainability (WB)]
		,c.[Calls_Started_2G_WO_Fails]
		,c.[Calls_Started_3G_WO_Fails]
		,c.[Calls_Started_4G_WO_Fails]
		,c.[Calls_Mixed]

		-- REAL VOLTE:
		,c.[VOLTE_SpeechDelay_Num]
		,c.[VOLTE_SpeechDelay_Den]
		,c.[VOLTE_Calls_Started_Ended_VOLTE]
		,c.[VOLTE_Calls_withSRVCC]
		,c.[VOLTE_Calls_is_VOLTE]
	  
		-- MOS:
		,m.[MOS_Num]
		,m.[MOS_Samples]
		,m.[1_WB], m.[2_WB], m.[3_WB], m.[4_WB]
		,m.[5_WB], m.[6_WB], m.[7_WB], m.[8_WB]	
		,m.[MOS Below 2.5 Samples WB],m.[MOS Over 3.5 Samples WB], m.[MOS ALL Samples WB]

		,m.[1_NB], m.[2_NB], m.[3_NB], m.[4_NB]
		,m.[5_NB], m.[6_NB], m.[7_NB], m.[8_NB]	
		,m.[MOS Below 2.5 Samples NB],m.[MOS Over 3.5 Samples NB], m.[MOS ALL Samples NB]  

		---- MOS QLil
		,m.[MOS_Samples_Under_2.5]
		,m.[MOS_NB_Samples_Under_2.5]
		,m.[Samples_DL+UL]
		,m.[Samples_DL+UL_NB]
		,m.[WB AMR Only]
		,m.[Avg WB AMR Only]

		---- MOS DASH:
		,m.[MOS_NB_Num]
		,m.[MOS_NB_Den]
		,m.[WB_AMR_Only_Num]
		,m.[WB_AMR_Only_Den]
		,m.[MOS_Overall_Samples_Under_2.5]

		-- CST:
		,t.[CST_ALERTING_NUM]
		,t.[CST_CONNECT_NUM]
		,t.[CST_MO_AL_samples]
		,t.[CST_MT_AL_samples]
		,t.[CST_MO_CO_samples]
		,t.[CST_MT_CO_samples]
		,t.[CST_MO_AL_NUM]
		,t.[CST_MT_AL_NUM]
		,t.[CST_MO_CO_NUM]
		,t.[CST_MT_CO_NUM]
		
		,t.[1_MO_A],	t.[2_MO_A],		t.[3_MO_A],		t.[4_MO_A],		t.[5_MO_A],		t.[6_MO_A],		t.[7_MO_A],		t.[8_MO_A],		t.[9_MO_A],		t.[10_MO_A],	t.[11_MO_A],	t.[12_MO_A],	t.[13_MO_A],	t.[14_MO_A],	t.[15_MO_A]
		,t.[16_MO_A],	t.[17_MO_A],	t.[18_MO_A],	t.[19_MO_A],	t.[20_MO_A],	t.[21_MO_A],	t.[22_MO_A],	t.[23_MO_A],	t.[24_MO_A],	t.[25_MO_A],	t.[26_MO_A],	t.[27_MO_A],	t.[28_MO_A],	t.[29_MO_A],	t.[30_MO_A]
		,t.[31_MO_A],	t.[32_MO_A],	t.[33_MO_A],	t.[34_MO_A],	t.[35_MO_A],	t.[36_MO_A],	t.[37_MO_A],	t.[38_MO_A],	t.[39_MO_A],	t.[40_MO_A],	t.[41_MO_A]

		,t.[1_MT_A],	t.[2_MT_A],		t.[3_MT_A],		t.[4_MT_A],		t.[5_MT_A],		t.[6_MT_A],		t.[7_MT_A],		t.[8_MT_A],		t.[9_MT_A],		t.[10_MT_A],	t.[11_MT_A],	t.[12_MT_A],	t.[13_MT_A],	t.[14_MT_A],	t.[15_MT_A]		
		,t.[16_MT_A],	t.[17_MT_A],	t.[18_MT_A],	t.[19_MT_A],	t.[20_MT_A],	t.[21_MT_A],	t.[22_MT_A],	t.[23_MT_A],	t.[24_MT_A],	t.[25_MT_A],	t.[26_MT_A],	t.[27_MT_A],	t.[28_MT_A],	t.[29_MT_A],	t.[30_MT_A]
		,t.[31_MT_A],	t.[32_MT_A],	t.[33_MT_A],	t.[34_MT_A],	t.[35_MT_A],	t.[36_MT_A],	t.[37_MT_A],	t.[38_MT_A],	t.[39_MT_A],	t.[40_MT_A],	t.[41_MT_A]
		
		,t.[1_MOMT_A],	t.[2_MOMT_A],	t.[3_MOMT_A],	t.[4_MOMT_A],	t.[5_MOMT_A],	t.[6_MOMT_A],	t.[7_MOMT_A],	t.[8_MOMT_A],	t.[9_MOMT_A],	t.[10_MOMT_A],	t.[11_MOMT_A],	t.[12_MOMT_A],	t.[13_MOMT_A],	t.[14_MOMT_A],	t.[15_MOMT_A]	
		,t.[16_MOMT_A],	t.[17_MOMT_A],	t.[18_MOMT_A],	t.[19_MOMT_A],	t.[20_MOMT_A],	t.[21_MOMT_A],	t.[22_MOMT_A],	t.[23_MOMT_A],	t.[24_MOMT_A],	t.[25_MOMT_A],	t.[26_MOMT_A],	t.[27_MOMT_A],	t.[28_MOMT_A],	t.[29_MOMT_A],	t.[30_MOMT_A]
		,t.[31_MOMT_A],	t.[32_MOMT_A],	t.[33_MOMT_A],	t.[34_MOMT_A],	t.[35_MOMT_A],	t.[36_MOMT_A],	t.[37_MOMT_A],	t.[38_MOMT_A],	t.[39_MOMT_A],	t.[40_MOMT_A],	t.[41_MOMT_A]

		,t.[1_MO_C],	t.[2_MO_C],		t.[3_MO_C],		t.[4_MO_C],		t.[5_MO_C],		t.[6_MO_C],		t.[7_MO_C],		t.[8_MO_C],		t.[9_MO_C],		t.[10_MO_C],	t.[11_MO_C],	t.[12_MO_C],	t.[13_MO_C],	t.[14_MO_C],	t.[15_MO_C]	
		,t.[16_MO_C],	t.[17_MO_C],	t.[18_MO_C],	t.[19_MO_C],	t.[20_MO_C],	t.[21_MO_C],	t.[22_MO_C],	t.[23_MO_C],	t.[24_MO_C],	t.[25_MO_C],	t.[26_MO_C],	t.[27_MO_C],	t.[28_MO_C],	t.[29_MO_C],	t.[30_MO_C]
		,t.[31_MO_C],	t.[32_MO_C],	t.[33_MO_C],	t.[34_MO_C],	t.[35_MO_C],	t.[36_MO_C],	t.[37_MO_C],	t.[38_MO_C],	t.[39_MO_C],	t.[40_MO_C],	t.[41_MO_C]

		,t.[1_MT_C],	t.[2_MT_C],		t.[3_MT_C],		t.[4_MT_C],		t.[5_MT_C],		t.[6_MT_C],		t.[7_MT_C],		t.[8_MT_C],		t.[9_MT_C],		t.[10_MT_C],	t.[11_MT_C],	t.[12_MT_C],	t.[13_MT_C],	t.[14_MT_C],	t.[15_MT_C]
		,t.[16_MT_C],	t.[17_MT_C],	t.[18_MT_C],	t.[19_MT_C],	t.[20_MT_C],	t.[21_MT_C],	t.[22_MT_C],	t.[23_MT_C],	t.[24_MT_C],	t.[25_MT_C],	t.[26_MT_C],	t.[27_MT_C],	t.[28_MT_C],	t.[29_MT_C],	t.[30_MT_C]
		,t.[31_MT_C],	t.[32_MT_C],	t.[33_MT_C],	t.[34_MT_C],	t.[35_MT_C],	t.[36_MT_C],	t.[37_MT_C],	t.[38_MT_C],	t.[39_MT_C],	t.[40_MT_C],	t.[41_MT_C]
		
		,t.[1_MOMT_C],	t.[2_MOMT_C],	t.[3_MOMT_C],	t.[4_MOMT_C],	t.[5_MOMT_C],	t.[6_MOMT_C],	t.[7_MOMT_C],	t.[8_MOMT_C],	t.[9_MOMT_C],	t.[10_MOMT_C],	t.[11_MOMT_C],	t.[12_MOMT_C],	t.[13_MOMT_C],	t.[14_MOMT_C],	t.[15_MOMT_C]
		,t.[16_MOMT_C],	t.[17_MOMT_C],	t.[18_MOMT_C],	t.[19_MOMT_C],	t.[20_MOMT_C],	t.[21_MOMT_C],	t.[22_MOMT_C],	t.[23_MOMT_C],	t.[24_MOMT_C],	t.[25_MOMT_C],	t.[26_MOMT_C],	t.[27_MOMT_C],	t.[28_MOMT_C],	t.[29_MOMT_C],	t.[30_MOMT_C]
		,t.[31_MOMT_C],	t.[32_MOMT_C],	t.[33_MOMT_C],	t.[34_MOMT_C],	t.[35_MOMT_C],	t.[36_MOMT_C],	t.[37_MOMT_C],	t.[38_MOMT_C],	t.[39_MOMT_C],	t.[40_MOMT_C],	t.[41_MOMT_C]

		-- CSFB:
		,cst_csfb.CST_ALERTING_UMTS_samples
		,cst_csfb.CST_ALERTING_UMTS900_samples		
		,cst_csfb.CST_ALERTING_UMTS2100_samples
		,cst_csfb.CST_ALERTING_GSM_samples
		,cst_csfb.CST_ALERTING_GSM900_samples
		,cst_csfb.CST_ALERTING_GSM1800_samples
		,cst_csfb.CST_ALERTING_UMTS_NUM
		,cst_csfb.CST_ALERTING_UMTS900_NUM
		,cst_csfb.CST_ALERTING_UMTS2100_NUM
		,cst_csfb.CST_ALERTING_GSM_NUM		
		,cst_csfb.CST_ALERTING_GSM900_NUM
		,cst_csfb.CST_ALERTING_GSM1800_NUM
		,cst_csfb.CST_CONNECT_UMTS_samples
		,cst_csfb.CST_CONNECT_UMTS900_samples		
		,cst_csfb.CST_CONNECT_UMTS2100_samples
		,cst_csfb.CST_CONNECT_GSM_samples
		,cst_csfb.CST_CONNECT_GSM900_samples
		,cst_csfb.CST_CONNECT_GSM1800_samples
		,cst_csfb.CST_CONNECT_UMTS_NUM
		,cst_csfb.CST_CONNECT_UMTS900_NUM
		,cst_csfb.CST_CONNECT_UMTS2100_NUM
		,cst_csfb.CST_CONNECT_GSM_NUM		
		,cst_csfb.CST_CONNECT_GSM900_NUM
		,cst_csfb.CST_CONNECT_GSM1800_NUM
		,cst_csfb.CSFB_duration_samples
		,cst_csfb.CSFB_duration_num

		,cst_csfb.MOS_2G_Num
		,cst_csfb.MOS_2G_Samples
		,cst_csfb.MOS_3G_Num
		,cst_csfb.MOS_3G_Samples
		,cst_csfb.MOS_GSM_Num
		,cst_csfb.MOS_GSM_Samples
		,cst_csfb.MOS_DCS_Num
		,cst_csfb.MOS_DCS_Samples
		,cst_csfb.MOS_UMTS900_Num
		,cst_csfb.MOS_UMTS900_Samples
		,cst_csfb.MOS_UMTS2100_Num
		,cst_csfb.MOS_UMTS2100_Samples

		,cst_csfb.Call_duration_UMTS2100
		,cst_csfb.Call_duration_UMTS900
		,cst_csfb.Call_duration_GSM
		,cst_csfb.Call_duration_DCS

		-- COBER 4G:
		,c4.coverage4G_den
		,c4.coverage4G_den_ProbCob
		,c4.[samples_4Gcov_num]
		,c4.[samples_L800cov_num]
		,c4.[samples_L1800cov_num]
		,c4.[samples_L2100cov_num]
		,c4.[samples_L2600cov_num]
		,c4.[samples_L800L1800cov_num]
		,c4.[samples_L800L2100cov_num]
		,c4.[samples_L800L2600cov_num]
		,c4.[samples_L1800L2100cov_num]
		,c4.[samples_L1800L2600cov_num]
		,c4.[samples_L2100L2600cov_num]
		,c4.[samples_L800L1800L2100cov_num]
		,c4.[samples_L800L1800L2600cov_num]
		,c4.[samples_L1800L2100L2600cov_num]
		,c4.[samples_L800L1800L2100L2600cov_num]
		,c4.[samples_L800L2100L2600cov_num]	  
		,c4.samples_L2100_BW5cov_num
		,c4.samples_L2100_BW10cov_num
		,c4.samples_L2100_BW15cov_num
		,c4.samples_L1800_BW10cov_num
		,c4.samples_L1800_BW15cov_num
		,c4.samples_L1800_BW20cov_num
		,c4.cobertura_AVG_4G_Num
		,c4.cobertura_AVG_L800_Num
		,c4.cobertura_AVG_L1800_Num
		,c4.cobertura_AVG_L2100_Num
		,c4.cobertura_AVG_L2600_Num
		,c4.samplesAVG_4G
		,c4.samplesAVG_L800
		,c4.samplesAVG_L1800
		,c4.samplesAVG_L2100
		,c4.samplesAVG_L2600
		,c4.LTE_ProbCobInd
		,c4.LTE2600_ProbCobInd
		,c4.LTE2100_ProbCobInd
		,c4.LTE2100_BW5_ProbCobInd
		,c4.LTE2100_BW10_ProbCobInd
		,c4.LTE2100_BW15_ProbCobInd
		,c4.LTE1800_ProbCobInd
		,c4.LTE1800_BW10_ProbCobInd
		,c4.LTE1800_BW15_ProbCobInd
		,c4.LTE1800_BW20_ProbCobInd
		,c4.LTE800_ProbCobInd
		,c4.LTE800_1800_ProbCobInd
		,c4.LTE800_2100_ProbCobInd
		,c4.LTE800_2600_ProbCobInd
		,c4.LTE1800_2100_ProbCobInd
		,c4.LTE1800_2600_ProbCobInd
		,c4.LTE2100_2600_ProbCobInd
		,c4.LTE800_1800_2100_ProbCobInd
		,c4.LTE800_1800_2600_ProbCobInd
		,c4.LTE800_2100_2600_ProbCobInd
		,c4.LTE1800_2100_2600_ProbCobInd
		,c4.LTE_Samples_ProbCobInd
		,c4.LTE2600_Samples_ProbCobInd
		,c4.LTE2100_Samples_ProbCobInd
		,c4.LTE2100_BW5_Samples_ProbCobInd
		,c4.LTE2100_BW10_Samples_ProbCobInd
		,c4.LTE2100_BW15_Samples_ProbCobInd
		,c4.LTE1800_Samples_ProbCobInd
		,c4.LTE1800_BW10_Samples_ProbCobInd
		,c4.LTE1800_BW15_Samples_ProbCobInd
		,c4.LTE1800_BW20_Samples_ProbCobInd
		,c4.LTE800_Samples_ProbCobInd
		,c4.LTE800_1800_Samples_ProbCobInd
		,c4.LTE800_2100_Samples_ProbCobInd
		,c4.LTE800_2600_Samples_ProbCobInd
		,c4.LTE1800_2100_Samples_ProbCobInd
		,c4.LTE1800_2600_Samples_ProbCobInd
		,c4.LTE2100_2600_Samples_ProbCobInd
		,c4.LTE800_1800_2100_Samples_ProbCobInd
		,c4.LTE800_1800_2600_Samples_ProbCobInd
		,c4.LTE800_2100_2600_Samples_ProbCobInd
		,c4.LTE1800_2100_2600_Samples_ProbCobInd

		-- COBER 3G:
		,c3.coverage3G_den
		,c3.coverage3G_den_ProbCob
		,c3.[samples_3Gcov_num]
		,c3.[samples_U2100cov_num]
		,c3.[samples_UMTS900cov_num]
		,c3.[samples_U900U2100cov_num]
		,c3.[samples_U2100_2Carriers_cov_num]
		,c3.[samples_U900U2100_2Carriers_cov_num]
		,c3.[samples_U2100_3Carriers_cov_num]
		,c3.[samples_U900U2100_3Carriers_cov_num]
		,c3.[samples_U2100_1Carriers_cov_num] 
		,c3.[UMTS2100_F1]
		,c3.[UMTS2100_F2]
		,c3.[UMTS2100_F3]
		,c3.[UMTS2100_P1]
		,c3.[UMTS2100_P2]
		,c3.[UMTS2100_P3]
		,c3.[UMTS900_F1]
		,c3.[UMTS900_F2]
		,c3.[UMTS900_P1]
		,c3.[UMTS900_P2]
		,c3.[UMTS2100_F1_F2]
		,c3.[UMTS2100_F1_F3]
		,c3.[UMTS2100_F2_F3]
		,c3.[UMTS900_U2100_F1]
		,c3.[UMTS900_U2100_F2]
		,c3.[UMTS900_U2100_F3]
		,c3.[UMTS900_U2100_F1_F2]
		,c3.[UMTS900_U2100_F1_F3]
		,c3.[UMTS900_U2100_F2_F3]
		,c3.cobertura_AVG_3G_Num
		,c3.cobertura_AVG_U2100_Num
		,c3.cobertura_AVG_U900_Num
		,c3.samplesAVG_3G
		,c3.samplesAVG_U2100
		,c3.samplesAVG_U900
		,c3.[Pollution]
		,c3.[Pollution BS Curves]
		,c3.[Pollution BS Curves UMTS2100]
		,c3.[Pollution BS Curves UMTS900]
		,c3.[Pollution BS RSCP]
		,c3.[Pollution BS RSCP UMTS2100]
		,c3.[Pollution BS RSCP UMTS900]
		,c3.UMTS_ProbCobInd
		,c3.UMTS2100_ProbCobInd
		,c3.UMTS2100_F1_ProbCobInd
		,c3.UMTS2100_F2_ProbCobInd
		,c3.UMTS2100_F3_ProbCobInd
		,c3.UMTS2100_P1_ProbCobInd
		,c3.UMTS2100_P2_ProbCobInd
		,c3.UMTS2100_P3_ProbCobInd
		,c3.UMTS2100_F1_F2_ProbCobInd
		,c3.UMTS2100_F1_F3_ProbCobInd
		,c3.UMTS2100_F2_F3_ProbCobInd
		,c3.UMTS2100_F1_F2_F3_ProbCobInd
		,c3.UMTS900_ProbCobInd
		,c3.UMTS900_F1_ProbCobInd
		,c3.UMTS900_F2_ProbCobInd
		,c3.UMTS900_P1_ProbCobInd
		,c3.UMTS900_P2_ProbCobInd
		,c3.UMTS900_U2100_F1_ProbCobInd
		,c3.UMTS900_U2100_F2_ProbCobInd
		,c3.UMTS900_U2100_F3_ProbCobInd
		,c3.UMTS900_U2100_F1_F2_ProbCobInd
		,c3.UMTS900_U2100_F1_F3_ProbCobInd
		,c3.UMTS900_U2100_F2_F3_ProbCobInd
		,c3.UMTS900_U2100_F1_F2_F3_ProbCobInd
		,c3.UMTS_Samples_ProbCobInd
		,c3.UMTS2100_Samples_ProbCobInd
		,c3.UMTS2100_F1_Samples_ProbCobInd
		,c3.UMTS2100_F2_Samples_ProbCobInd
		,c3.UMTS2100_F3_Samples_ProbCobInd
		,c3.UMTS2100_P1_Samples_ProbCobInd
		,c3.UMTS2100_P2_Samples_ProbCobInd
		,c3.UMTS2100_P3_Samples_ProbCobInd
		,c3.UMTS2100_F1_F2_Samples_ProbCobInd
		,c3.UMTS2100_F1_F3_Samples_ProbCobInd
		,c3.UMTS2100_F2_F3_Samples_ProbCobInd
		,c3.UMTS2100_F1_F2_F3_Samples_ProbCobInd
		,c3.UMTS900_Samples_ProbCobInd
		,c3.UMTS900_F1_Samples_ProbCobInd
		,c3.UMTS900_F2_Samples_ProbCobInd
		,c3.UMTS900_P1_Samples_ProbCobInd
		,c3.UMTS900_P2_Samples_ProbCobInd
		,c3.UMTS900_U2100_F1_Samples_ProbCobInd
		,c3.UMTS900_U2100_F2_Samples_ProbCobInd
		,c3.UMTS900_U2100_F3_Samples_ProbCobInd
		,c3.UMTS900_U2100_F1_F2_Samples_ProbCobInd
		,c3.UMTS900_U2100_F1_F3_Samples_ProbCobInd
		,c3.UMTS900_U2100_F2_F3_Samples_ProbCobInd
		,c3.UMTS900_U2100_F1_F2_F3_Samples_ProbCobInd
		,c3.[UMTS2100_Carrier_only_ProbCobInd]
		,c3.[UMTS2100_Dual_Carrier_ProbCobInd]
		,c3.[UMTS900_U2100_Carrier_only_ProbCobInd]
		,c3.[UMTS900_U2100_Dual_Carrier_ProbCobInd]
		,c3.[UMTS2100_Carrier_only_Samples_ProbCobInd]
		,c3.[UMTS2100_Dual_Carrier_Samples_ProbCobInd]
		,c3.[UMTS900_U2100_Carrier_only_Samples_ProbCobInd]
		,c3.[UMTS900_U2100_Dual_Carrier_Samples_ProbCobInd]

		-- COBER 2G:
		,c2.coverage2G_den
		,c2.coverage2G_den_ProbCob
		,c2.samples_2Gcov_num
		,c2.samples_GSMcov_num
		,c2.samples_DCScov_num
		,c2.samples_GSMDCScov_num
		,c2.cobertura_AVG_2G_Num
		,c2.cobertura_AVG_GSM_Num
		,c2.cobertura_AVG_DCS_Num
		,c2.samplesAVG_2G
		,c2.samplesAVG_GSM
		,c2.samplesAVG_DCS
		,c2.[2G_ProbCobInd]
		,c2.GSM_ProbCobInd
		,c2.DCS_ProbCobInd
		,c2.GSM_DCS_ProbCobInd
		,c2.[2G_Samples_ProbCobInd]
		,c2.GSM_Samples_ProbCobInd
		,c2.DCS_Samples_ProbCobInd
		,c2.GSM_DCS_Samples_ProbCobInd

		,e.POB13 as 'Poblacion',

		-- Se le añade las REGIONES solo a carreteras y AVES, ya que en entidades puede meter desglose extra en los casos en los que se salga (carreteras sobre todo)
		-- 1) Este sera el campo relleno solo para ROADS - QLIK - ¿aves no?
		--case when b.vf_environment ='ave' or (b.vf_environment = 'roads' and b.meas_Tech like '%Road%') then p.Region_VF else NULL end as Region_Road_VF,
		--case when b.vf_environment ='ave' or (b.vf_environment = 'roads' and b.meas_Tech like '%Road%') then p.Region_OSP else NULL end as Region_Road_OSP,
		case when (b.vf_environment = 'roads' and b.meas_Tech like '%Road%') then p.Region_VF else NULL end as Region_Road_VF,		-- mete RX
		case when (b.vf_environment = 'roads' and b.meas_Tech like '%Road%') then p.Region_OSP else NULL end as Region_Road_OSP,	-- mete Rx

		-- 2) Este sera el campo relleno para TODO:
		case when b.vf_environment ='ave' or (b.vf_environment = 'roads' and b.meas_Tech like '%Road%') then p.Region_VF else NULL end as Region_VF,
		case when b.vf_environment ='ave' or (b.vf_environment = 'roads' and b.meas_Tech like '%Road%') then p.Region_OSP else NULL end as Region_OSP,

		c.[ASideDevice], c.[BSideDevice], c.[SWVersion]

	into _RI_Voice_result1
	from 
		_RI_Voice_base b
		left outer join (	-- Cada codigo_ine es unico por provincia y CCAA
					select codigo_ine, provincia, CCAA	/*, count(*)*/	
							,Region_VF, Region_OSP
					from [AGRIDS].[dbo].vlcc_parcelas_OSP
					group by codigo_ine, provincia, CCAA ,Region_VF, Region_OSP
					--having count(*)>1
					) p on isnull(b.codigo_ine,0)=isnull(p.codigo_ine,0) 

		left outer join _RI_Voice_c c on 
			isnull(b.codigo_ine,0)=isnull(c.codigo_ine,0) and  b.mnc=c.mnc and isnull(b.meas_round,0)=isnull(c.meas_round,0)
			and b.meas_date=c.meas_date and b.meas_week=c.meas_week 
			and b.meas_Tech=c.meas_Tech and b.vf_entity=c.vf_entity and b.vf_environment=c.vf_environment
			and b.Report_Type=c.Report_Type and b.Aggr_Type=c.Aggr_Type
			--and isnull(b.Region_Road_VF,0)=isnull(c.Region_Road_VF,0)
			--and isnull(b.Region_Road_OSP,0)=isnull(c.Region_Road_OSP,0)
			--and isnull(b.Region_VF,0)=isnull(c.Region_VF,0)
			--and isnull(b.Region_OSP,0)=isnull(c.Region_OSP,0)
			and isnull(b.calltype,0)=isnull(c.calltype,0)
			and isnull(b.ASideDevice,0)=isnull(c.ASideDevice,0)
			and isnull(b.BSideDevice,0)=isnull(c.BSideDevice,0)
			and isnull(b.SWVersion,0)=isnull(c.SWVersion,0)

		left outer join _RI_Voice_m m on 
			isnull(b.codigo_ine,0)=isnull(m.codigo_ine,0) and  b.mnc=m.mnc and isnull(b.meas_round,0)=isnull(m.meas_round,0)
			and b.meas_date=m.meas_date and b.meas_week=m.meas_week 
			and b.meas_Tech=m.meas_Tech and b.vf_entity=m.vf_entity and b.vf_environment=m.vf_environment
			and b.Report_Type=m.Report_Type and b.Aggr_Type=m.Aggr_Type
			--and isnull(b.Region_Road_VF,0)=isnull(m.Region_Road_VF,0)
			--and isnull(b.Region_Road_OSP,0)=isnull(m.Region_Road_OSP,0)
			--and isnull(b.Region_VF,0)=isnull(m.Region_VF,0)
			--and isnull(b.Region_OSP,0)=isnull(m.Region_OSP,0)
			and isnull(b.calltype,0)=isnull(m.calltype,0)
			and isnull(b.ASideDevice,0)=isnull(m.ASideDevice,0)
			and isnull(b.BSideDevice,0)=isnull(m.BSideDevice,0)
			and isnull(b.SWVersion,0)=isnull(m.SWVersion,0)

		left outer join _RI_Voice_cst t on 
			isnull(b.codigo_ine,0)=isnull(t.codigo_ine,0) and  b.mnc=t.mnc and isnull(b.meas_round,0)=isnull(t.meas_round,0)
			and b.meas_date=t.meas_date and b.meas_week=t.meas_week 
			and b.meas_Tech=t.meas_Tech and b.vf_entity=t.vf_entity and b.vf_environment=t.vf_environment
			and b.Report_Type=t.Report_Type and b.Aggr_Type=t.Aggr_Type
			--and isnull(b.Region_Road_VF,0)=isnull(t.Region_Road_VF,0)
			--and isnull(b.Region_Road_OSP,0)=isnull(t.Region_Road_OSP,0)
			--and isnull(b.Region_VF,0)=isnull(t.Region_VF,0)
			--and isnull(b.Region_OSP,0)=isnull(t.Region_OSP,0)
			and isnull(b.calltype,0)=isnull(t.calltype,0)
			and isnull(b.ASideDevice,0)=isnull(t.ASideDevice,0)
			and isnull(b.BSideDevice,0)=isnull(t.BSideDevice,0)
			and isnull(b.SWVersion,0)=isnull(t.SWVersion,0)

		left outer join _RI_Voice_cober4G c4 on 
			isnull(b.codigo_ine,0)=isnull(c4.codigo_ine,0) and  b.mnc=c4.mnc and isnull(b.meas_round,0)=isnull(c4.meas_round,0)
			and b.meas_date=c4.meas_date and b.meas_week=c4.meas_week 
			and b.meas_Tech=c4.meas_Tech and b.vf_entity=c4.vf_entity and b.vf_environment=c4.vf_environment
			and b.Report_Type=c4.Report_Type and b.Aggr_Type=c4.Aggr_Type
			--and isnull(b.Region_Road_VF,0)=isnull(c4.Region_Road_VF,0)
			--and isnull(b.Region_Road_OSP,0)=isnull(c4.Region_Road_OSP,0)
			--and isnull(b.Region_VF,0)=isnull(c4.Region_VF,0)
			--and isnull(b.Region_OSP,0)=isnull(c4.Region_OSP,0)
			and isnull(b.calltype,0)=isnull(c4.calltype,0)
			and isnull(b.ASideDevice,0)=isnull(c4.ASideDevice,0)
			and isnull(b.BSideDevice,0)=isnull(c4.BSideDevice,0)
			and isnull(b.SWVersion,0)=isnull(c4.SWVersion,0)

		left outer join _RI_Voice_cober3G c3 on 
			isnull(b.codigo_ine,0)=isnull(c3.codigo_ine,0) and  b.mnc=c3.mnc and isnull(b.meas_round,0)=isnull(c3.meas_round,0)
			and b.meas_date=c3.meas_date and b.meas_week=c3.meas_week 
			and b.meas_Tech=c3.meas_Tech and b.vf_entity=c3.vf_entity and b.vf_environment=c3.vf_environment 
			and b.Report_Type=c3.Report_Type and b.Aggr_Type=c3.Aggr_Type
			--and isnull(b.Region_Road_VF,0)=isnull(c3.Region_Road_VF,0)
			--and isnull(b.Region_Road_OSP,0)=isnull(c3.Region_Road_OSP,0)
			--and isnull(b.Region_VF,0)=isnull(c3.Region_VF,0)
			--and isnull(b.Region_OSP,0)=isnull(c3.Region_OSP,0)
			and isnull(b.calltype,0)=isnull(c3.calltype,0)
			and isnull(b.ASideDevice,0)=isnull(c3.ASideDevice,0)
			and isnull(b.BSideDevice,0)=isnull(c3.BSideDevice,0)
			and isnull(b.SWVersion,0)=isnull(c3.SWVersion,0)

		left outer join _RI_Voice_cober2G c2 on 
			isnull(b.codigo_ine,0)=isnull(c2.codigo_ine,0) and  b.mnc=c2.mnc and isnull(b.meas_round,0)=isnull(c2.meas_round,0)
			and b.meas_date=c2.meas_date and b.meas_week=c2.meas_week 
			and b.meas_Tech=c2.meas_Tech and b.vf_entity=c2.vf_entity and b.vf_environment=c2.vf_environment 
			and b.Report_Type=c2.Report_Type and b.Aggr_Type=c2.Aggr_Type
			--and isnull(b.Region_Road_VF,0)=isnull(c2.Region_Road_VF,0)
			--and isnull(b.Region_Road_OSP,0)=isnull(c2.Region_Road_OSP,0)
			--and isnull(b.Region_VF,0)=isnull(c2.Region_VF,0)
			--and isnull(b.Region_OSP,0)=isnull(c2.Region_OSP,0)
			and isnull(b.calltype,0)=isnull(c2.calltype,0)
			and isnull(b.ASideDevice,0)=isnull(c2.ASideDevice,0)
			and isnull(b.BSideDevice,0)=isnull(c2.BSideDevice,0)
			and isnull(b.SWVersion,0)=isnull(c2.SWVersion,0)

		left outer join _RI_Voice_cst_csfb cst_csfb on 
			isnull(b.codigo_ine,0)=isnull(cst_csfb.codigo_ine,0) and  b.mnc=cst_csfb.mnc and isnull(b.meas_round,0)=isnull(cst_csfb.meas_round,0)
			and b.meas_date=cst_csfb.meas_date and b.meas_week=cst_csfb.meas_week 
			and b.meas_Tech=cst_csfb.meas_Tech and b.vf_entity=cst_csfb.vf_entity and b.vf_environment=cst_csfb.vf_environment 
			and b.Report_Type=cst_csfb.Report_Type and b.Aggr_Type=cst_csfb.Aggr_Type
			--and isnull(b.Region_Road_VF,0)=isnull(cst_csfb.Region_Road_VF,0)
			--and isnull(b.Region_Road_OSP,0)=isnull(cst_csfb.Region_Road_OSP,0)
			--and isnull(b.Region_VF,0)=isnull(cst_csfb.Region_VF,0)
			--and isnull(b.Region_OSP,0)=isnull(cst_csfb.Region_OSP,0)
			and isnull(b.calltype,0)=isnull(cst_csfb.calltype,0)
			and isnull(b.ASideDevice,0)=isnull(cst_csfb.ASideDevice,0)
			and isnull(b.BSideDevice,0)=isnull(cst_csfb.BSideDevice,0)
			and isnull(b.SWVersion,0)=isnull(cst_csfb.SWVersion,0)
		  
		left join (
					select max(pob13) as pob13,entity_name --Por si hay duplicados
					from [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] 
					group by entity_name
					) e on b.vf_entity=e.entity_name

	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 15. Primer union de todas las tablas temporales -> _RI_Voice_result1', getdate()

	------------------------------------------------------------------------------
	-- 16.Update _RI_Voice_result1
	------------------------------------------------------------------------------
	print '16. Update _RI_Voice_result1'
	-----------
	-- Unificamos el codigo INE para las entidades que no sean roads ni carreteras
	update _RI_Voice_result1
	set codigo_ine=e.ine
	from _RI_Voice_result1 r, [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] e
	where r.entity=e.entity_name 
		--Hay parcelas de roads en entidades que no son roads (su tipo de medida no contiene Road)
		and (r.environment not in ('roads','ave') or (r.environment = 'roads' and r.meas_Tech not like '%Road%'))

	-----------
	-- Se actualiza la info de PROVINCIA y CCAA a estas entidades:
	update _RI_Voice_result1
		set Provincia=e.Provincia,
			CCAA=e.CCAA,
			Region_VF=e.Region_VF,		--				REPLACE(e.Zona_VF, 'Region', 'R'),		-- mete RegionX
			Region_OSP=e.Region_OSP		--				REPLACE(e.Zona_OSP, 'Zona', 'R')		-- mete ZonaX - que es la que queremos
		from _RI_Voice_result1 r, [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] e
		where r.entity=e.entity_name 
			--Hay parcelas de roads en entidades que no son roads (su tipo de medida no contiene Road)
			and (r.environment not in ('roads','ave') or (r.environment = 'roads' and r.meas_Tech not like '%Road%'))

	---------------------------------------
	-- Quitamos el codigo INE para aves y carreteras 
	update _RI_Voice_result1
	set codigo_ine=''
	where environment ='ave' or (environment = 'roads' and meas_Tech like '%Road%')

	---------------------------------------
	-- Contamos el numero de entornos diferentes por cada n-upla de registro base:
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result1_info'
	select codigo_ine, count(distinct environment) as 'num_entornos',
			mnc,meas_round,meas_date,meas_week,meas_Tech,entity,id_vdf,id_osp,id_osp_noComp,Report_Type
	into _RI_Voice_result1_info
	from _RI_Voice_result1
	group by codigo_ine,mnc,meas_round,meas_date,meas_week,meas_Tech,entity,id_vdf,id_osp,id_osp_noComp,Report_Type

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 16. Update _RI_Voice_result1 y cuenta de entornos diferentes', getdate()

	 ------------------------------------------------------------------------------
	 -- 17. El resultado se pone en 2 veces, para añadir el codigo ine en función de la entidad
	 --    y evitar malentendidos en codigos ine colindantes en parcelas
	------------------------------------------------------------------------------
	print '17. Se añade codigo INE en funcion de la entidad'
	-----------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result1_Pob_Entidad'
	select 
		b.codigo_ine,
		case  b.mnc 
			when'01' then 'Vodafone' 
			when '03' then 'Orange' 
			when '07' then 'Movistar' 
			when '04' then 'Yoigo' 
		end as operator,
		b.mnc,b.meas_round,b.meas_date,b.meas_week,b.meas_Tech,b.VF_entity as entity
	
		,c4.coverage4G_den	  
		,c4.LTE_ProbCobInd
		,c4.LTE_Samples_ProbCobInd
		,c3.coverage3G_den	
		,c3.UMTS_ProbCobInd	
		,c3.UMTS_Samples_ProbCobInd	
		,c2.coverage2G_den
		,c2.[2G_ProbCobInd]	
		,c2.[2G_Samples_ProbCobInd]
		,e.POB13 as 'Poblacion'

	into _RI_Voice_result1_Pob_Entidad
	from 
		_RI_Voice_base_Pob_Entidad b 
		left outer join _RI_Voice_cober4G_Pob_Entidad c4 on 
			b.codigo_ine=c4.codigo_ine and  b.mnc=c4.mnc and isnull(b.meas_round,0)=isnull(c4.meas_round,0)
			and b.meas_date=c4.meas_date and b.meas_week=c4.meas_week 
			and b.meas_Tech=c4.meas_Tech and b.vf_entity=c4.vf_entity
			and b.Report_Type=c4.Report_Type and b.Aggr_Type=c4.Aggr_Type
		left outer join _RI_Voice_cober3G_Pob_Entidad c3 on 
			b.codigo_ine=c3.codigo_ine and  b.mnc=c3.mnc and isnull(b.meas_round,0)=isnull(c3.meas_round,0)
			and b.meas_date=c3.meas_date and b.meas_week=c3.meas_week 
			and b.meas_Tech=c3.meas_Tech and b.vf_entity=c3.vf_entity
			and b.Report_Type=c3.Report_Type and b.Aggr_Type=c3.Aggr_Type
		left outer join _RI_Voice_cober2G_Pob_Entidad c2 on 
			b.codigo_ine=c2.codigo_ine and  b.mnc=c2.mnc and isnull(b.meas_round,0)=isnull(c2.meas_round,0)
			and b.meas_date=c2.meas_date and b.meas_week=c2.meas_week 
			and b.meas_Tech=c2.meas_Tech and b.vf_entity=c2.vf_entity
			and b.Report_Type=c2.Report_Type and b.Aggr_Type=c2.Aggr_Type
		left join (
				select max(pob13) as pob13,entity_name --Por si hay duplicados
				from [AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] 
				group by entity_name
				)e
			on b.vf_entity=e.entity_name

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 17. Se añade codigo INE en funcion de la entidad', getdate()


	------------------------------------------------------------------------------
	-- 18. Tablas y KPIs para cob poblacional
	------------------------------------------------------------------------------
	print '18. Tablas y KPIs para cob poblacional'
	-----------
	update _RI_Voice_result1_Pob_Entidad
	set codigo_ine=e.ine
	from 
		_RI_Voice_result1_Pob_Entidad r,
		[AGRIDS_v2].[dbo].[lcc_ciudades_tipo_Project_V9] e
	where r.entity=e.entity_name

	------------------------------------
	 --Calculamos KPIs de cober poblacional en cada desglose de entidad
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result2_Pob_Entidad'
	select 
		codigo_ine,
		operator,
		mnc,meas_round,meas_date,meas_week,meas_Tech,entity, Poblacion
		,isnull(sum(LTE_ProbCobInd)/nullif(sum(coverage4G_den),0),0) as 'LTE_ProbCobInd_Pob_Entidad'
		,isnull(sum(UMTS_ProbCobInd)/nullif(sum(coverage3G_den),0),0) as 'UMTS_ProbCobInd_Pob_Entidad'
		,isnull(sum([2G_ProbCobInd])/nullif(sum(coverage2G_den),0),0) as '2G_ProbCobInd_Pob_Entidad'
	into _RI_Voice_result2_Pob_Entidad
	from _RI_Voice_result1_Pob_Entidad
	group by codigo_ine,operator,mnc,meas_round,meas_date,meas_week,meas_Tech,entity, Poblacion

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 18. Tablas y KPIs para cob poblacional', getdate()


	------------------------------------------------------------------------------
	-- Agrupamos por el mismo codigo INE (único por entidad en el punto anterior¿?)
	-- y concatenamos los KPIS de cober ponderada por poblacion a nivel de entidad ( mismo info en cada tipo de enviorement)

	-- 19. Montamos la tabla	->  _RI_Voice_result_INE_only
	------------------------------------------------------------------------------
	print '19. Montamos la tabla	->  _RI_Voice_result_INE_only'
	-----------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result_INE_only'
	select 
		r.codigo_ine, r.Provincia, r.CCAA,
		r.environment,r.operator,r.mnc,r.meas_round,r.meas_date,r.meas_week,r.meas_Tech,r.Report_Type,r.id_vdf,r.id_osp,r.id_osp_noComp,
		case when (r.environment ='ave' or (r.environment = 'roads' and r.meas_Tech like '%Road%')) 
			then reverse(Substring(reverse(r.entity),charindex('-',reverse(r.entity))+1,len(reverse(r.entity))))
		else r.entity end as 'entity',
		case when r.entity like '%-R[0-9]%' 
			then Substring(r.entity,len(r.entity)-charindex('-',reverse(r.entity))+2,3) 
		else '' end as 'Round', 
		max(r.Poblacion/Num_entornos) as 'Poblacion'
	
		,r.calltype
	
		-- Calls:
		,sum([MOC_Calls]) as [MOC_Calls]
		,sum([MTC_Calls]) as [MTC_Calls]
		,sum([MOC_Blocks]) as [MOC_Blocks]
		,sum([MTC_Blocks]) as [MTC_Blocks]
		,sum([MOC_Drops]) as [MOC_Drops]
		,sum([MTC_Drops]) as [MTC_Drops]
		,sum([Calls]) as [Calls]
		,sum([Blocks]) as [Blocks]
		,sum([Drops]) as [Drops]
		,sum([CR_Affected_Calls]) as [CR_Affected_Calls]
		,sum(Call_duration_3G) as Call_duration_3G
		,sum(Call_duration_2G) as Call_duration_2G
		,sum(Call_duration_tech_samples) as Call_duration_tech_samples
		,sum(CSFB_to_GSM_samples) as CSFB_to_GSM_samples
		,sum(CSFB_to_UMTS_samples) as CSFB_to_UMTS_samples
		,sum(CSFB_samples) as CSFB_samples
		,sum([NUMBERS OF CALLS Non Sustainability (NB)]) as [NUMBERS OF CALLS Non Sustainability (NB)]
		,sum([NUMBERS OF CALLS Non Sustainability (WB)]) as [NUMBERS OF CALLS Non Sustainability (WB)]
		,sum([Calls_Started_2G_WO_Fails]) as [Calls_Started_2G_WO_Fails]
		,sum([Calls_Started_3G_WO_Fails]) as [Calls_Started_3G_WO_Fails]
		,sum([Calls_Started_4G_WO_Fails]) as [Calls_Started_4G_WO_Fails]
		,sum([Calls_Mixed]) as [Calls_Mixed]

		-- REAL VOLTE:
		,sum([VOLTE_SpeechDelay_Num]) as [VOLTE_SpeechDelay_Num]
		,sum([VOLTE_SpeechDelay_Den]) as [VOLTE_SpeechDelay_Den]
		,sum([VOLTE_Calls_Started_Ended_VOLTE]) as [VOLTE_Calls_Started_Ended_VOLTE]
		,sum([VOLTE_Calls_withSRVCC]) as [VOLTE_Calls_withSRVCC]
		,sum([VOLTE_Calls_is_VOLTE]) as [VOLTE_Calls_is_VOLTE]

		-- MOS:
		,sum([MOS_Num]) as [MOS_Num]
		,sum([MOS_Samples]) as [MOS_Samples]
		,sum(AMR_FR_samples) as AMR_FR_samples
		,sum(AMR_HR_samples) as AMR_HR_samples
		,sum(AMR_WB_samples) as AMR_WB_samples
		,sum(FR_samples) as FR_samples
		,sum(EFR_samples) as EFR_samples
		,sum(HR_samples) as HR_samples
		,sum(codec_samples)  as codec_samples
		,sum([1_WB]) as [1_WB]	,sum([2_WB]) as [2_WB]	,sum([3_WB]) as [3_WB]
		,sum([4_WB]) as [4_WB]	,sum([5_WB]) as [5_WB]	,sum([6_WB]) as [6_WB]
		,sum([7_WB]) as [7_WB]	,sum([8_WB]) as [8_WB]	
		,sum([MOS Below 2.5 Samples WB]) as [MOS Below 2.5 Samples WB]
		,sum([MOS Over 3.5 Samples WB]) as [MOS Over 3.5 Samples WB]	
		,sum([MOS ALL Samples WB]) as [MOS ALL Samples WB]

		,sum([1_NB]) as [1_NB]	,sum([2_NB]) as [2_NB]	,sum([3_NB]) as [3_NB]	
		,sum([4_NB]) as [4_NB]	,sum([5_NB]) as [5_NB]	,sum([6_NB]) as [6_NB]	
		,sum([7_NB]) as [7_NB]	,sum([8_NB]) as [8_NB]	
		,sum([MOS Below 2.5 Samples NB]) as [MOS Below 2.5 Samples NB]
		,sum([MOS Over 3.5 Samples NB]) as [MOS Over 3.5 Samples NB]
		,sum([MOS ALL Samples NB]) as [MOS ALL Samples NB]	

		---- QLIK:
		,sum([MOS_Samples_Under_2.5]) as [MOS_Samples_Under_2.5]
		,sum([MOS_NB_Samples_Under_2.5]) as [MOS_NB_Samples_Under_2.5]
		,sum([Samples_DL+UL]) as [Samples_DL+UL]
		,sum([Samples_DL+UL_NB]) as [Samples_DL+UL_NB]
		,sum([WB AMR Only]) as [WB AMR Only]
		,sum([Avg WB AMR Only]) as [Avg WB AMR Only]

		----DASH:
		,sum([MOS_NB_Num]) as [MOS_NB_Num]
		,sum([MOS_NB_Den]) as [MOS_NB_Den]
		,sum([WB_AMR_Only_Num]) as [WB_AMR_Only_Num]
		,sum([WB_AMR_Only_Den]) as [WB_AMR_Only_Den]
		,sum([MOS_Overall_Samples_Under_2.5]) as [MOS_Overall_Samples_Under_2.5]

		-- CST:
		,sum([CST_ALERTING_NUM]) as [CST_ALERTING_NUM]
		,sum([CST_CONNECT_NUM]) as [CST_CONNECT_NUM]
		,sum(CST_MO_AL_samples) as CST_MO_AL_samples
		,sum(CST_MT_AL_samples) as CST_MT_AL_samples
		,sum(CST_MO_CO_samples) as CST_MO_CO_samples
		,sum(CST_MT_CO_samples) as CST_MT_CO_samples
		,sum([CST_MO_AL_NUM]) as [CST_MO_AL_NUM]
		,sum([CST_MT_AL_NUM]) as [CST_MT_AL_NUM]
		,sum([CST_MO_CO_NUM]) as [CST_MO_CO_NUM]
		,sum([CST_MT_CO_NUM]) as [CST_MT_CO_NUM]

		,sum(CST_ALERTING_UMTS_samples) as CST_ALERTING_UMTS_samples
		,sum(CST_ALERTING_UMTS900_samples) as CST_ALERTING_UMTS900_samples
		,sum(CST_ALERTING_UMTS2100_samples) as CST_ALERTING_UMTS2100_samples
		,sum(CST_ALERTING_GSM_samples) as CST_ALERTING_GSM_samples
		,sum(CST_ALERTING_GSM900_samples) as CST_ALERTING_GSM900_samples
		,sum(CST_ALERTING_GSM1800_samples) as CST_ALERTING_GSM1800_samples
		,sum(CST_ALERTING_UMTS_NUM) as CST_ALERTING_UMTS_NUM
		,sum(CST_ALERTING_UMTS900_NUM) as CST_ALERTING_UMTS900_NUM
		,sum(CST_ALERTING_UMTS2100_NUM) as CST_ALERTING_UMTS2100_NUM
		,sum(CST_ALERTING_GSM_NUM) as CST_ALERTING_GSM_NUM
		,sum(CST_ALERTING_GSM900_NUM) as CST_ALERTING_GSM900_NUM
		,sum(CST_ALERTING_GSM1800_NUM) as CST_ALERTING_GSM1800_NUM
		,sum(CST_CONNECT_UMTS_samples) as CST_CONNECT_UMTS_samples
		,sum(CST_CONNECT_UMTS900_samples) as CST_CONNECT_UMTS900_samples
		,sum(CST_CONNECT_UMTS2100_samples) as CST_CONNECT_UMTS2100_samples
		,sum(CST_CONNECT_GSM_samples) as CST_CONNECT_GSM_samples
		,sum(CST_CONNECT_GSM900_samples) as CST_CONNECT_GSM900_samples
		,sum(CST_CONNECT_GSM1800_samples) as CST_CONNECT_GSM1800_samples
		,sum(CST_CONNECT_UMTS_NUM) as CST_CONNECT_UMTS_NUM
		,sum(CST_CONNECT_UMTS900_NUM) as CST_CONNECT_UMTS900_NUM
		,sum(CST_CONNECT_UMTS2100_NUM) as CST_CONNECT_UMTS2100_NUM
		,sum(CST_CONNECT_GSM_NUM) as CST_CONNECT_GSM_NUM
		,sum(CST_CONNECT_GSM900_NUM) as CST_CONNECT_GSM900_NUM
		,sum(CST_CONNECT_GSM1800_NUM) as CST_CONNECT_GSM1800_NUM
		,sum(CSFB_duration_samples) as CSFB_duration_samples
		,sum(CSFB_duration_num) as CSFB_duration_num

		,sum( [1_MO_A]) as [1_MO_A]
		,sum( [2_MO_A]) as  [2_MO_A]
		,sum( [3_MO_A]) as  [3_MO_A]
		,sum( [4_MO_A]) as  [4_MO_A]
		,sum( [5_MO_A]) as  [5_MO_A]
		,sum( [6_MO_A]) as  [6_MO_A]
		,sum( [7_MO_A]) as  [7_MO_A]
		,sum( [8_MO_A]) as  [8_MO_A]
		,sum( [9_MO_A]) as  [9_MO_A]
		,sum( [10_MO_A]) as  [10_MO_A]
		,sum( [11_MO_A]) as  [11_MO_A]
		,sum( [12_MO_A]) as  [12_MO_A]
		,sum( [13_MO_A]) as  [13_MO_A]
		,sum( [14_MO_A]) as  [14_MO_A]
		,sum( [15_MO_A]) as  [15_MO_A]
		,sum( [16_MO_A]) as  [16_MO_A]
		,sum( [17_MO_A]) as  [17_MO_A]
		,sum( [18_MO_A]) as  [18_MO_A]
		,sum( [19_MO_A]) as  [19_MO_A]
		,sum( [20_MO_A]) as  [20_MO_A]
		,sum( [21_MO_A]) as  [21_MO_A]
		,sum( [22_MO_A]) as  [22_MO_A]
		,sum( [23_MO_A]) as  [23_MO_A]
		,sum( [24_MO_A]) as  [24_MO_A]
		,sum( [25_MO_A]) as  [25_MO_A]
		,sum( [26_MO_A]) as  [26_MO_A]
		,sum( [27_MO_A]) as  [27_MO_A]
		,sum( [28_MO_A]) as  [28_MO_A]
		,sum( [29_MO_A]) as  [29_MO_A]
		,sum( [30_MO_A]) as  [30_MO_A]
		,sum( [31_MO_A]) as [31_MO_A]
		,sum( [32_MO_A]) as [32_MO_A]
		,sum( [33_MO_A]) as [33_MO_A]
		,sum( [34_MO_A]) as [34_MO_A]
		,sum( [35_MO_A]) as [35_MO_A]
		,sum( [36_MO_A]) as [36_MO_A]
		,sum( [37_MO_A]) as [37_MO_A]
		,sum( [38_MO_A]) as [38_MO_A]
		,sum( [39_MO_A]) as [39_MO_A]
		,sum( [40_MO_A]) as [40_MO_A]
		,sum( [41_MO_A]) as [41_MO_A]

		,sum( [1_MT_A]) as  [1_MT_A]
		,sum( [2_MT_A]) as  [2_MT_A]
		,sum( [3_MT_A]) as  [3_MT_A]
		,sum( [4_MT_A]) as  [4_MT_A]
		,sum( [5_MT_A]) as  [5_MT_A]
		,sum( [6_MT_A]) as  [6_MT_A]
		,sum( [7_MT_A]) as  [7_MT_A]
		,sum( [8_MT_A]) as  [8_MT_A]
		,sum( [9_MT_A]) as  [9_MT_A]
		,sum( [10_MT_A]) as  [10_MT_A]
		,sum( [11_MT_A]) as  [11_MT_A]
		,sum( [12_MT_A]) as  [12_MT_A]
		,sum( [13_MT_A]) as  [13_MT_A]
		,sum( [14_MT_A]) as  [14_MT_A]
		,sum( [15_MT_A]) as  [15_MT_A]
		,sum( [16_MT_A]) as  [16_MT_A]
		,sum( [17_MT_A]) as  [17_MT_A]
		,sum( [18_MT_A]) as  [18_MT_A]
		,sum( [19_MT_A]) as  [19_MT_A]
		,sum( [20_MT_A]) as  [20_MT_A]
		,sum( [21_MT_A]) as  [21_MT_A]
		,sum( [22_MT_A]) as  [22_MT_A]
		,sum( [23_MT_A]) as  [23_MT_A]
		,sum( [24_MT_A]) as  [24_MT_A]
		,sum( [25_MT_A]) as  [25_MT_A]
		,sum( [26_MT_A]) as  [26_MT_A]
		,sum( [27_MT_A]) as  [27_MT_A]
		,sum( [28_MT_A]) as  [28_MT_A]
		,sum( [29_MT_A]) as  [29_MT_A]
		,sum( [30_MT_A]) as  [30_MT_A]
		,sum( [31_MT_A]) as [31_MT_A]
		,sum( [32_MT_A]) as [32_MT_A]
		,sum( [33_MT_A]) as [33_MT_A]
		,sum( [34_MT_A]) as [34_MT_A]
		,sum( [35_MT_A]) as [35_MT_A]
		,sum( [36_MT_A]) as [36_MT_A]
		,sum( [37_MT_A]) as [37_MT_A]
		,sum( [38_MT_A]) as [38_MT_A]
		,sum( [39_MT_A]) as [39_MT_A]
		,sum( [40_MT_A]) as [40_MT_A]
		,sum( [41_MT_A]) as [41_MT_A]

		,sum( [1_MOMT_A]) as  [1_MOMT_A]
		,sum( [2_MOMT_A]) as  [2_MOMT_A]
		,sum( [3_MOMT_A]) as  [3_MOMT_A]
		,sum( [4_MOMT_A]) as  [4_MOMT_A]
		,sum( [5_MOMT_A]) as  [5_MOMT_A]
		,sum( [6_MOMT_A]) as  [6_MOMT_A]
		,sum( [7_MOMT_A]) as  [7_MOMT_A]
		,sum( [8_MOMT_A]) as  [8_MOMT_A]
		,sum( [9_MOMT_A]) as  [9_MOMT_A]
		,sum( [10_MOMT_A]) as  [10_MOMT_A]
		,sum( [11_MOMT_A]) as  [11_MOMT_A]
		,sum( [12_MOMT_A]) as  [12_MOMT_A]
		,sum( [13_MOMT_A]) as  [13_MOMT_A]
		,sum( [14_MOMT_A]) as  [14_MOMT_A]
		,sum( [15_MOMT_A]) as  [15_MOMT_A]
		,sum( [16_MOMT_A]) as  [16_MOMT_A]
		,sum( [17_MOMT_A]) as  [17_MOMT_A]
		,sum( [18_MOMT_A]) as  [18_MOMT_A]
		,sum( [19_MOMT_A]) as  [19_MOMT_A]
		,sum( [20_MOMT_A]) as  [20_MOMT_A]
		,sum( [21_MOMT_A]) as  [21_MOMT_A]
		,sum( [22_MOMT_A]) as  [22_MOMT_A]
		,sum( [23_MOMT_A]) as  [23_MOMT_A]
		,sum( [24_MOMT_A]) as  [24_MOMT_A]
		,sum( [25_MOMT_A]) as  [25_MOMT_A]
		,sum( [26_MOMT_A]) as  [26_MOMT_A]
		,sum( [27_MOMT_A]) as  [27_MOMT_A]
		,sum( [28_MOMT_A]) as  [28_MOMT_A]
		,sum( [29_MOMT_A]) as  [29_MOMT_A]
		,sum( [30_MOMT_A]) as  [30_MOMT_A]
		,sum( [31_MOMT_A]) as [31_MOMT_A]
		,sum( [32_MOMT_A]) as [32_MOMT_A]
		,sum( [33_MOMT_A]) as [33_MOMT_A]
		,sum( [34_MOMT_A]) as [34_MOMT_A]
		,sum( [35_MOMT_A]) as [35_MOMT_A]
		,sum( [36_MOMT_A]) as [36_MOMT_A]
		,sum( [37_MOMT_A]) as [37_MOMT_A]
		,sum( [38_MOMT_A]) as [38_MOMT_A]
		,sum( [39_MOMT_A]) as [39_MOMT_A]
		,sum( [40_MOMT_A]) as [40_MOMT_A]
		,sum( [41_MOMT_A]) as [41_MOMT_A]

		,sum( [1_MO_C]) as  [1_MO_C]
		,sum( [2_MO_C]) as  [2_MO_C]
		,sum( [3_MO_C]) as  [3_MO_C]
		,sum( [4_MO_C]) as  [4_MO_C]
		,sum( [5_MO_C]) as  [5_MO_C]
		,sum( [6_MO_C]) as  [6_MO_C]
		,sum( [7_MO_C]) as  [7_MO_C]
		,sum( [8_MO_C]) as  [8_MO_C]
		,sum( [9_MO_C]) as  [9_MO_C]
		,sum( [10_MO_C]) as  [10_MO_C]
		,sum( [11_MO_C]) as  [11_MO_C]
		,sum( [12_MO_C]) as  [12_MO_C]
		,sum( [13_MO_C]) as  [13_MO_C]
		,sum( [14_MO_C]) as  [14_MO_C]
		,sum( [15_MO_C]) as  [15_MO_C]
		,sum( [16_MO_C]) as  [16_MO_C]
		,sum( [17_MO_C]) as  [17_MO_C]
		,sum( [18_MO_C]) as  [18_MO_C]
		,sum( [19_MO_C]) as  [19_MO_C]
		,sum( [20_MO_C]) as  [20_MO_C]
		,sum( [21_MO_C]) as  [21_MO_C]
		,sum( [22_MO_C]) as  [22_MO_C]
		,sum( [23_MO_C]) as  [23_MO_C]
		,sum( [24_MO_C]) as  [24_MO_C]
		,sum( [25_MO_C]) as  [25_MO_C]
		,sum( [26_MO_C]) as  [26_MO_C]
		,sum( [27_MO_C]) as  [27_MO_C]
		,sum( [28_MO_C]) as  [28_MO_C]
		,sum( [29_MO_C]) as  [29_MO_C]
		,sum( [30_MO_C]) as  [30_MO_C]
		,sum( [31_MO_C]) as [31_MO_C]
		,sum( [32_MO_C]) as [32_MO_C]
		,sum( [33_MO_C]) as [33_MO_C]
		,sum( [34_MO_C]) as [34_MO_C]
		,sum( [35_MO_C]) as [35_MO_C]
		,sum( [36_MO_C]) as [36_MO_C]
		,sum( [37_MO_C]) as [37_MO_C]
		,sum( [38_MO_C]) as [38_MO_C]
		,sum( [39_MO_C]) as [39_MO_C]
		,sum( [40_MO_C]) as [40_MO_C]
		,sum( [41_MO_C]) as [41_MO_C]

		,sum( [1_MT_C]) as  [1_MT_C]
		,sum( [2_MT_C]) as  [2_MT_C]
		,sum( [3_MT_C]) as  [3_MT_C]
		,sum( [4_MT_C]) as  [4_MT_C]
		,sum( [5_MT_C]) as  [5_MT_C]
		,sum( [6_MT_C]) as  [6_MT_C]
		,sum( [7_MT_C]) as  [7_MT_C]
		,sum( [8_MT_C]) as  [8_MT_C]
		,sum( [9_MT_C]) as  [9_MT_C]
		,sum( [10_MT_C]) as  [10_MT_C]
		,sum( [11_MT_C]) as  [11_MT_C]
		,sum( [12_MT_C]) as  [12_MT_C]
		,sum( [13_MT_C]) as  [13_MT_C]
		,sum( [14_MT_C]) as  [14_MT_C]
		,sum( [15_MT_C]) as  [15_MT_C]
		,sum( [16_MT_C]) as  [16_MT_C]
		,sum( [17_MT_C]) as  [17_MT_C]
		,sum( [18_MT_C]) as  [18_MT_C]
		,sum( [19_MT_C]) as  [19_MT_C]
		,sum( [20_MT_C]) as  [20_MT_C]
		,sum( [21_MT_C]) as  [21_MT_C]
		,sum( [22_MT_C]) as  [22_MT_C]
		,sum( [23_MT_C]) as  [23_MT_C]
		,sum( [24_MT_C]) as  [24_MT_C]
		,sum( [25_MT_C]) as  [25_MT_C]
		,sum( [26_MT_C]) as  [26_MT_C]
		,sum( [27_MT_C]) as  [27_MT_C]
		,sum( [28_MT_C]) as  [28_MT_C]
		,sum( [29_MT_C]) as  [29_MT_C]
		,sum( [30_MT_C]) as  [30_MT_C]
		,sum( [31_MT_C]) as [31_MT_C]
		,sum( [32_MT_C]) as [32_MT_C]
		,sum( [33_MT_C]) as [33_MT_C]
		,sum( [34_MT_C]) as [34_MT_C]
		,sum( [35_MT_C]) as [35_MT_C]
		,sum( [36_MT_C]) as [36_MT_C]
		,sum( [37_MT_C]) as [37_MT_C]
		,sum( [38_MT_C]) as [38_MT_C]
		,sum( [39_MT_C]) as [39_MT_C]
		,sum( [40_MT_C]) as [40_MT_C]
		,sum( [41_MT_C]) as [41_MT_C]

		,sum( [1_MOMT_C]) as  [1_MOMT_C]
		,sum( [2_MOMT_C]) as  [2_MOMT_C]
		,sum( [3_MOMT_C]) as  [3_MOMT_C]
		,sum( [4_MOMT_C]) as  [4_MOMT_C]
		,sum( [5_MOMT_C]) as  [5_MOMT_C]
		,sum( [6_MOMT_C]) as  [6_MOMT_C]
		,sum( [7_MOMT_C]) as  [7_MOMT_C]
		,sum( [8_MOMT_C]) as  [8_MOMT_C]
		,sum( [9_MOMT_C]) as  [9_MOMT_C]
		,sum( [10_MOMT_C]) as  [10_MOMT_C]
		,sum( [11_MOMT_C]) as  [11_MOMT_C]
		,sum( [12_MOMT_C]) as  [12_MOMT_C]
		,sum( [13_MOMT_C]) as  [13_MOMT_C]
		,sum( [14_MOMT_C]) as  [14_MOMT_C]
		,sum( [15_MOMT_C]) as  [15_MOMT_C]
		,sum( [16_MOMT_C]) as  [16_MOMT_C]
		,sum( [17_MOMT_C]) as  [17_MOMT_C]
		,sum( [18_MOMT_C]) as  [18_MOMT_C]
		,sum( [19_MOMT_C]) as  [19_MOMT_C]
		,sum( [20_MOMT_C]) as  [20_MOMT_C]
		,sum( [21_MOMT_C]) as  [21_MOMT_C]
		,sum( [22_MOMT_C]) as  [22_MOMT_C]
		,sum( [23_MOMT_C]) as  [23_MOMT_C]
		,sum( [24_MOMT_C]) as  [24_MOMT_C]
		,sum( [25_MOMT_C]) as  [25_MOMT_C]
		,sum( [26_MOMT_C]) as  [26_MOMT_C]
		,sum( [27_MOMT_C]) as  [27_MOMT_C]
		,sum( [28_MOMT_C]) as  [28_MOMT_C]
		,sum( [29_MOMT_C]) as  [29_MOMT_C]
		,sum( [30_MOMT_C]) as  [30_MOMT_C]
		,sum( [31_MOMT_C]) as [31_MOMT_C]
		,sum( [32_MOMT_C]) as [32_MOMT_C]
		,sum( [33_MOMT_C]) as [33_MOMT_C]
		,sum( [34_MOMT_C]) as [34_MOMT_C]
		,sum( [35_MOMT_C]) as [35_MOMT_C]
		,sum( [36_MOMT_C]) as [36_MOMT_C]
		,sum( [37_MOMT_C]) as [37_MOMT_C]
		,sum( [38_MOMT_C]) as [38_MOMT_C]
		,sum( [39_MOMT_C]) as [39_MOMT_C]
		,sum( [40_MOMT_C]) as [40_MOMT_C]
		,sum( [41_MOMT_C]) as [41_MOMT_C]

		,sum(MOS_2G_Num) as MOS_2G_Num
		,sum(MOS_2G_Samples) as MOS_2G_Samples
		,sum(MOS_3G_Num) as MOS_3G_Num
		,sum(MOS_3G_Samples) as MOS_3G_Samples
		,sum(MOS_GSM_Num) as MOS_GSM_Num
		,sum(MOS_GSM_Samples) as MOS_GSM_Samples
		,sum(MOS_DCS_Num) as MOS_DCS_Num
		,sum(MOS_DCS_Samples) as MOS_DCS_Samples
		,sum(MOS_UMTS900_Num) as MOS_UMTS900_Num
		,sum(MOS_UMTS900_Samples) as MOS_UMTS900_Samples
		,sum(MOS_UMTS2100_Num) as MOS_UMTS2100_Num
		,sum(MOS_UMTS2100_Samples) as MOS_UMTS2100_Samples
		,sum(Call_duration_UMTS2100) as Call_duration_UMTS2100
		,sum(Call_duration_UMTS900) as Call_duration_UMTS900
		,sum(Call_duration_GSM) as Call_duration_GSM
		,sum(Call_duration_DCS) as Call_duration_DCS

		-- COBER 4G:
		,sum(coverage4G_den) as coverage4G_den
		,sum(coverage4G_den_ProbCob) as coverage4G_den_ProbCob
		,sum([samples_4Gcov_num]) as [samples_4Gcov_num]
		,sum([samples_L800cov_num]) as [samples_L800cov_num]
		,sum([samples_L1800cov_num]) as [samples_L1800cov_num]
		,sum([samples_L2100cov_num]) as [samples_L2100cov_num]
		,sum([samples_L2600cov_num]) as [samples_L2600cov_num]
		,sum([samples_L800L1800cov_num]) as [samples_L800L1800cov_num]
		,sum([samples_L800L2100cov_num]) as [samples_L800L2100cov_num]
		,sum([samples_L800L2600cov_num]) as [samples_L800L2600cov_num]
		,sum([samples_L1800L2100cov_num]) as [samples_L1800L2100cov_num]
		,sum([samples_L1800L2600cov_num]) as [samples_L1800L2600cov_num]
		,sum([samples_L2100L2600cov_num]) as [samples_L2100L2600cov_num]
		,sum([samples_L800L1800L2100cov_num]) as [samples_L800L1800L2100cov_num]
		,sum([samples_L800L1800L2600cov_num]) as [samples_L800L1800L2600cov_num]
		,sum([samples_L1800L2100L2600cov_num]) as [samples_L1800L2100L2600cov_num]
		,sum([samples_L800L1800L2100L2600cov_num]) as [samples_L800L1800L2100L2600cov_num]
		,sum([samples_L800L2100L2600cov_num]) as [samples_L800L2100L2600cov_num]	  
		,sum(samples_L2100_BW5cov_num) as samples_L2100_BW5cov_num
		,sum(samples_L2100_BW10cov_num) as samples_L2100_BW10cov_num
		,sum(samples_L2100_BW15cov_num) as samples_L2100_BW15cov_num
		,sum(samples_L1800_BW10cov_num) as samples_L1800_BW10cov_num
		,sum(samples_L1800_BW15cov_num) as samples_L1800_BW15cov_num
		,sum(samples_L1800_BW20cov_num) as samples_L1800_BW20cov_num
		,sum(cobertura_AVG_4G_Num) as cobertura_AVG_4G_Num
		,sum(cobertura_AVG_L800_Num) as cobertura_AVG_L800_Num
		,sum(cobertura_AVG_L1800_Num) as cobertura_AVG_L1800_Num
		,sum(cobertura_AVG_L2100_Num) as cobertura_AVG_L2100_Num
		,sum(cobertura_AVG_L2600_Num) as cobertura_AVG_L2600_Num
		,sum(samplesAVG_4G) as samplesAVG_4G
		,sum(samplesAVG_L800) as samplesAVG_L800
		,sum(samplesAVG_L1800) as samplesAVG_L1800
		,sum(samplesAVG_L2100) as samplesAVG_L2100
		,sum(samplesAVG_L2600) as samplesAVG_L2600
		,sum(LTE_ProbCobInd) as LTE_ProbCobInd
		,sum(LTE2600_ProbCobInd) as LTE2600_ProbCobInd
		,sum(LTE2100_ProbCobInd) as LTE2100_ProbCobInd
		,sum(LTE2100_BW5_ProbCobInd) as LTE2100_BW5_ProbCobInd
		,sum(LTE2100_BW10_ProbCobInd) as LTE2100_BW10_ProbCobInd
		,sum(LTE2100_BW15_ProbCobInd) as LTE2100_BW15_ProbCobInd
		,sum(LTE1800_ProbCobInd) as LTE1800_ProbCobInd
		,sum(LTE1800_BW10_ProbCobInd) as LTE1800_BW10_ProbCobInd
		,sum(LTE1800_BW15_ProbCobInd) as LTE1800_BW15_ProbCobInd
		,sum(LTE1800_BW20_ProbCobInd) as LTE1800_BW20_ProbCobInd
		,sum(LTE800_ProbCobInd) as LTE800_ProbCobInd
		,sum(LTE800_1800_ProbCobInd) as LTE800_1800_ProbCobInd
		,sum(LTE800_2100_ProbCobInd) as LTE800_2100_ProbCobInd
		,sum(LTE800_2600_ProbCobInd) as LTE800_2600_ProbCobInd
		,sum(LTE1800_2100_ProbCobInd) as LTE1800_2100_ProbCobInd
		,sum(LTE1800_2600_ProbCobInd) as LTE1800_2600_ProbCobInd
		,sum(LTE2100_2600_ProbCobInd) as LTE2100_2600_ProbCobInd
		,sum(LTE800_1800_2100_ProbCobInd) as LTE800_1800_2100_ProbCobInd
		,sum(LTE800_1800_2600_ProbCobInd) as LTE800_1800_2600_ProbCobInd
		,sum(LTE800_2100_2600_ProbCobInd) as LTE800_2100_2600_ProbCobInd
		,sum(LTE1800_2100_2600_ProbCobInd) as LTE1800_2100_2600_ProbCobInd
		,sum(LTE_Samples_ProbCobInd) as LTE_Samples_ProbCobInd
		,sum(LTE2600_Samples_ProbCobInd) as LTE2600_Samples_ProbCobInd
		,sum(LTE2100_Samples_ProbCobInd) as LTE2100_Samples_ProbCobInd
		,sum(LTE2100_BW5_Samples_ProbCobInd) as LTE2100_BW5_Samples_ProbCobInd
		,sum(LTE2100_BW10_Samples_ProbCobInd) as LTE2100_BW10_Samples_ProbCobInd
		,sum(LTE2100_BW15_Samples_ProbCobInd) as LTE2100_BW15_Samples_ProbCobInd
		,sum(LTE1800_Samples_ProbCobInd) as LTE1800_Samples_ProbCobInd
		,sum(LTE1800_BW10_Samples_ProbCobInd) as LTE1800_BW10_Samples_ProbCobInd
		,sum(LTE1800_BW15_Samples_ProbCobInd) as LTE1800_BW15_Samples_ProbCobInd
		,sum(LTE1800_BW20_Samples_ProbCobInd) as LTE1800_BW20_Samples_ProbCobInd
		,sum(LTE800_Samples_ProbCobInd) as LTE800_Samples_ProbCobInd
		,sum(LTE800_1800_Samples_ProbCobInd) as LTE800_1800_Samples_ProbCobInd
		,sum(LTE800_2100_Samples_ProbCobInd) as LTE800_2100_Samples_ProbCobInd
		,sum(LTE800_2600_Samples_ProbCobInd) as LTE800_2600_Samples_ProbCobInd
		,sum(LTE1800_2100_Samples_ProbCobInd) as LTE1800_2100_Samples_ProbCobInd
		,sum(LTE1800_2600_Samples_ProbCobInd) as LTE1800_2600_Samples_ProbCobInd
		,sum(LTE2100_2600_Samples_ProbCobInd) as LTE2100_2600_Samples_ProbCobInd
		,sum(LTE800_1800_2100_Samples_ProbCobInd) as LTE800_1800_2100_Samples_ProbCobInd
		,sum(LTE800_1800_2600_Samples_ProbCobInd) as LTE800_1800_2600_Samples_ProbCobInd
		,sum(LTE800_2100_2600_Samples_ProbCobInd) as LTE800_2100_2600_Samples_ProbCobInd
		,sum(LTE1800_2100_2600_Samples_ProbCobInd) as LTE1800_2100_2600_Samples_ProbCobInd
		
		-- COBER 3G:
		,sum(coverage3G_den) as coverage3G_den
		,sum(coverage3G_den_ProbCob) as coverage3G_den_ProbCob
		,sum([samples_3Gcov_num]) as [samples_3Gcov_num]
		,sum([samples_U2100cov_num]) as [samples_U2100cov_num]
		,sum([samples_UMTS900cov_num]) as [samples_UMTS900cov_num]
		,sum([samples_U900U2100cov_num]) as [samples_U900U2100cov_num]
		,sum([samples_U2100_2Carriers_cov_num]) as [samples_U2100_2Carriers_cov_num]
		,sum([samples_U900U2100_2Carriers_cov_num]) as [samples_U900U2100_2Carriers_cov_num]
		,sum([samples_U2100_3Carriers_cov_num]) as [samples_U2100_3Carriers_cov_num]
		,sum([samples_U900U2100_3Carriers_cov_num]) as [samples_U900U2100_3Carriers_cov_num]
		,sum([samples_U2100_1Carriers_cov_num])  as [samples_U2100_1Carriers_cov_num]
		,sum([UMTS2100_F1]) as [UMTS2100_F1]
		,sum([UMTS2100_F2]) as [UMTS2100_F2]
		,sum([UMTS2100_F3]) as [UMTS2100_F3]
		,sum([UMTS2100_P1]) as [UMTS2100_P1]
		,sum([UMTS2100_P2]) as [UMTS2100_P2]
		,sum([UMTS2100_P3]) as [UMTS2100_P3]
		,sum([UMTS900_F1]) as [UMTS900_F1]
		,sum([UMTS900_F2]) as [UMTS900_F2]
		,sum([UMTS900_P1]) as [UMTS900_P1]
		,sum([UMTS900_P2]) as [UMTS900_P2]
		,sum([UMTS2100_F1_F2]) as [UMTS2100_F1_F2]
		,sum([UMTS2100_F1_F3]) as [UMTS2100_F1_F3]
		,sum([UMTS2100_F2_F3]) as [UMTS2100_F2_F3]
		,sum([UMTS900_U2100_F1]) as [UMTS900_U2100_F1]
		,sum([UMTS900_U2100_F2]) as [UMTS900_U2100_F2]
		,sum([UMTS900_U2100_F3]) as [UMTS900_U2100_F3]
		,sum([UMTS900_U2100_F1_F2]) as [UMTS900_U2100_F1_F2]
		,sum([UMTS900_U2100_F1_F3]) as [UMTS900_U2100_F1_F3]
		,sum([UMTS900_U2100_F2_F3]) as [UMTS900_U2100_F2_F3]
		,sum(cobertura_AVG_3G_Num) as cobertura_AVG_3G_Num
		,sum(cobertura_AVG_U2100_Num) as cobertura_AVG_U2100_Num
		,sum(cobertura_AVG_U900_Num) as cobertura_AVG_U900_Num
		,sum(samplesAVG_3G) as samplesAVG_3G
		,sum(samplesAVG_U2100) as samplesAVG_U2100
		,sum(samplesAVG_U900) as samplesAVG_U900
		,sum([Pollution]) as [Pollution]
		,sum([Pollution BS Curves]) as [Pollution BS Curves]
		,sum([Pollution BS Curves UMTS2100]) as [Pollution BS Curves UMTS2100]
		,sum([Pollution BS Curves UMTS900]) as [Pollution BS Curves UMTS900]
		,sum([Pollution BS RSCP]) as [Pollution BS RSCP]
		,sum([Pollution BS RSCP UMTS2100]) as [Pollution BS RSCP UMTS2100]
		,sum([Pollution BS RSCP UMTS900]) as [Pollution BS RSCP UMTS900]
		,sum(UMTS_ProbCobInd) as UMTS_ProbCobInd
		,sum(UMTS2100_ProbCobInd) as UMTS2100_ProbCobInd
		,sum(UMTS2100_F1_ProbCobInd) as UMTS2100_F1_ProbCobInd
		,sum(UMTS2100_F2_ProbCobInd) as UMTS2100_F2_ProbCobInd
		,sum(UMTS2100_F3_ProbCobInd) as UMTS2100_F3_ProbCobInd
		,sum(UMTS2100_P1_ProbCobInd) as UMTS2100_P1_ProbCobInd
		,sum(UMTS2100_P2_ProbCobInd) as UMTS2100_P2_ProbCobInd
		,sum(UMTS2100_P3_ProbCobInd) as UMTS2100_P3_ProbCobInd
		,sum(UMTS2100_F1_F2_ProbCobInd) as UMTS2100_F1_F2_ProbCobInd
		,sum(UMTS2100_F1_F3_ProbCobInd) as UMTS2100_F1_F3_ProbCobInd
		,sum(UMTS2100_F2_F3_ProbCobInd) as UMTS2100_F2_F3_ProbCobInd
		,sum(UMTS2100_F1_F2_F3_ProbCobInd) as UMTS2100_F1_F2_F3_ProbCobInd
		,sum(UMTS900_ProbCobInd) as UMTS900_ProbCobInd
		,sum(UMTS900_F1_ProbCobInd) as UMTS900_F1_ProbCobInd
		,sum(UMTS900_F2_ProbCobInd) as UMTS900_F2_ProbCobInd
		,sum(UMTS900_P1_ProbCobInd) as UMTS900_P1_ProbCobInd
		,sum(UMTS900_P2_ProbCobInd) as UMTS900_P2_ProbCobInd
		,sum(UMTS900_U2100_F1_ProbCobInd) as UMTS900_U2100_F1_ProbCobInd
		,sum(UMTS900_U2100_F2_ProbCobInd) as UMTS900_U2100_F2_ProbCobInd
		,sum(UMTS900_U2100_F3_ProbCobInd) as UMTS900_U2100_F3_ProbCobInd
		,sum(UMTS900_U2100_F1_F2_ProbCobInd) as UMTS900_U2100_F1_F2_ProbCobInd
		,sum(UMTS900_U2100_F1_F3_ProbCobInd) as UMTS900_U2100_F1_F3_ProbCobInd
		,sum(UMTS900_U2100_F2_F3_ProbCobInd) as UMTS900_U2100_F2_F3_ProbCobInd
		,sum(UMTS900_U2100_F1_F2_F3_ProbCobInd) as UMTS900_U2100_F1_F2_F3_ProbCobInd
		,sum(UMTS_Samples_ProbCobInd) as UMTS_Samples_ProbCobInd
		,sum(UMTS2100_Samples_ProbCobInd) as UMTS2100_Samples_ProbCobInd
		,sum(UMTS2100_F1_Samples_ProbCobInd) as UMTS2100_F1_Samples_ProbCobInd
		,sum(UMTS2100_F2_Samples_ProbCobInd) as UMTS2100_F2_Samples_ProbCobInd
		,sum(UMTS2100_F3_Samples_ProbCobInd) as UMTS2100_F3_Samples_ProbCobInd
		,sum(UMTS2100_P1_Samples_ProbCobInd) as UMTS2100_P1_Samples_ProbCobInd
		,sum(UMTS2100_P2_Samples_ProbCobInd) as UMTS2100_P2_Samples_ProbCobInd
		,sum(UMTS2100_P3_Samples_ProbCobInd) as UMTS2100_P3_Samples_ProbCobInd
		,sum(UMTS2100_F1_F2_Samples_ProbCobInd) as UMTS2100_F1_F2_Samples_ProbCobInd
		,sum(UMTS2100_F1_F3_Samples_ProbCobInd) as UMTS2100_F1_F3_Samples_ProbCobInd
		,sum(UMTS2100_F2_F3_Samples_ProbCobInd) as UMTS2100_F2_F3_Samples_ProbCobInd
		,sum(UMTS2100_F1_F2_F3_Samples_ProbCobInd) as UMTS2100_F1_F2_F3_Samples_ProbCobInd
		,sum(UMTS900_Samples_ProbCobInd) as UMTS900_Samples_ProbCobInd
		,sum(UMTS900_F1_Samples_ProbCobInd) as UMTS900_F1_Samples_ProbCobInd
		,sum(UMTS900_F2_Samples_ProbCobInd) as UMTS900_F2_Samples_ProbCobInd
		,sum(UMTS900_P1_Samples_ProbCobInd) as UMTS900_P1_Samples_ProbCobInd
		,sum(UMTS900_P2_Samples_ProbCobInd) as UMTS900_P2_Samples_ProbCobInd
		,sum(UMTS900_U2100_F1_Samples_ProbCobInd) as UMTS900_U2100_F1_Samples_ProbCobInd
		,sum(UMTS900_U2100_F2_Samples_ProbCobInd) as UMTS900_U2100_F2_Samples_ProbCobInd
		,sum(UMTS900_U2100_F3_Samples_ProbCobInd) as UMTS900_U2100_F3_Samples_ProbCobInd
		,sum(UMTS900_U2100_F1_F2_Samples_ProbCobInd) as UMTS900_U2100_F1_F2_Samples_ProbCobInd
		,sum(UMTS900_U2100_F1_F3_Samples_ProbCobInd) as UMTS900_U2100_F1_F3_Samples_ProbCobInd
		,sum(UMTS900_U2100_F2_F3_Samples_ProbCobInd) as UMTS900_U2100_F2_F3_Samples_ProbCobInd
		,sum(UMTS900_U2100_F1_F2_F3_Samples_ProbCobInd) as UMTS900_U2100_F1_F2_F3_Samples_ProbCobInd
		,sum([UMTS2100_Carrier_only_ProbCobInd]) as [UMTS2100_Carrier_only_ProbCobInd]
		,sum([UMTS2100_Dual_Carrier_ProbCobInd]) as [UMTS2100_Dual_Carrier_ProbCobInd]
		,sum([UMTS900_U2100_Carrier_only_ProbCobInd]) as [UMTS900_U2100_Carrier_only_ProbCobInd]
		,sum([UMTS900_U2100_Dual_Carrier_ProbCobInd]) as [UMTS900_U2100_Dual_Carrier_ProbCobInd]
		,sum([UMTS2100_Carrier_only_Samples_ProbCobInd]) as [UMTS2100_Carrier_only_Samples_ProbCobInd]
		,sum([UMTS2100_Dual_Carrier_Samples_ProbCobInd]) as [UMTS2100_Dual_Carrier_Samples_ProbCobInd]
		,sum([UMTS900_U2100_Carrier_only_Samples_ProbCobInd]) as [UMTS900_U2100_Carrier_only_Samples_ProbCobInd]
		,sum([UMTS900_U2100_Dual_Carrier_Samples_ProbCobInd]) as [UMTS900_U2100_Dual_Carrier_Samples_ProbCobInd]
		
		-- COBER 2G:
		,sum(coverage2G_den) as coverage2G_den
		,sum(coverage2G_den_ProbCob) as coverage2G_den_ProbCob
		,sum(samples_2Gcov_num) as samples_2Gcov_num
		,sum(samples_GSMcov_num) as samples_GSMcov_num
		,sum(samples_DCScov_num) as samples_DCScov_num
		,sum(samples_GSMDCScov_num) as samples_GSMDCScov_num
		,sum(cobertura_AVG_2G_Num) as cobertura_AVG_2G_Num
		,sum(cobertura_AVG_GSM_Num) as cobertura_AVG_GSM_Num
		,sum(cobertura_AVG_DCS_Num) as cobertura_AVG_DCS_Num
		,sum(samplesAVG_2G) as samplesAVG_2G
		,sum(samplesAVG_GSM) as samplesAVG_GSM
		,sum(samplesAVG_DCS) as samplesAVG_DCS
		,sum([2G_ProbCobInd]) as [2G_ProbCobInd]
		,sum(GSM_ProbCobInd) as GSM_ProbCobInd
		,sum(DCS_ProbCobInd) as DCS_ProbCobInd
		,sum(GSM_DCS_ProbCobInd) as GSM_DCS_ProbCobInd
		,sum([2G_Samples_ProbCobInd]) as [2G_Samples_ProbCobInd]
		,sum(GSM_Samples_ProbCobInd) as GSM_Samples_ProbCobInd
		,sum(DCS_Samples_ProbCobInd) as DCS_Samples_ProbCobInd
		,sum(GSM_DCS_Samples_ProbCobInd) as GSM_DCS_Samples_ProbCobInd

		,min((e.LTE_ProbCobInd_Pob_Entidad*e.poblacion)/Num_entornos) as 'LTE_ProbCobInd_Pob_Entidad'	--unico valor por entidad
		,min((e.UMTS_ProbCobInd_Pob_Entidad*e.poblacion)/Num_entornos) as 'UMTS_ProbCobInd_Pob_Entidad' --unico valor por entidad
		,min((e.[2G_ProbCobInd_Pob_Entidad]*e.poblacion)/Num_entornos) as '2G_ProbCobInd_Pob_Entidad'	--unico valor por entidad

		,r.Region_Road_VF, r.Region_Road_OSP
		,r.Region_VF, r.Region_OSP,  
		r.[ASideDevice], r.[BSideDevice], r.[SWVersion]

	into _RI_Voice_result_INE_only
	from _RI_Voice_result1 r
			inner join _RI_Voice_result1_info i
					on (r.codigo_ine = i.codigo_ine and  r.mnc=i.mnc and isnull(r.meas_round,0)=isnull(i.meas_round,0)
						and r.meas_date = i.meas_date and r.meas_week=i.meas_week 
						and r.meas_Tech = i.meas_Tech and r.entity=i.entity
						and r.id_vdf = i.id_vdf
						and r.id_osp = i.id_osp
						and r.id_osp_noComp = i.id_osp_noComp
						)
						
			left join _RI_Voice_result2_Pob_Entidad e
					on r.codigo_ine = e.codigo_ine and r.operator = e.operator and r.mnc = e.mnc 
						and r.meas_round = e.meas_round and r.meas_date = e.meas_date and r.meas_week = e.meas_week and r.meas_Tech = e.meas_Tech and r.entity = e.entity

	group by 
		r.codigo_ine, r.Provincia, r.CCAA,
		r.environment,r.operator,r.mnc,r.meas_round,r.meas_date,r.meas_week,r.meas_Tech,r.entity,r.poblacion,r.Report_Type,
		r.id_vdf,r.id_osp, r.id_osp_noComp, r.Region_Road_VF, r.Region_Road_OSP, r.Region_VF, r.Region_OSP
		,r.callType, r.[ASideDevice], r.[BSideDevice], r.[SWVersion]

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 19. Montamos la tabla	->  _RI_Voice_result_INE_only', getdate()

	------------------------------------------------------------------------------
	-- 20. Montamos la tabla -> _result
	------------------------------------------------------------------------------
	print '20. Montamos la tabla -> _RI_Voice_result'
	-----------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result'
	select 
		b.*,
		-- Se cogen las ya obtenidas anteriormente (de vlcc_parcelas para ROADS y AVEs y V9 para entidades) - se hace asi por mantener el orden que ya hay, por si afecta a otros procs
		b.provincia as Provincia_V9,	
		b.CCAA as CCAA_V9,					
		p.rango_pobl, p.resp_sharing, o.completed,		--p.zona_OSP,  p.Zona_VDF, 

		-- Este es un campo nuevo, en V9 existe solo para entidades, por eso ya lo calcumao directamnte sobre todo (viene del mismo lado para las entidades)
		replace(b.Provincia, '_', ' ') as Provincia_comp,	
		
		case 
			when b.environment ='ave' then 'RAILWAYS'				
			when (b.environment = 'roads' and b.meas_Tech like '%Road%') then 'MAIN HIGHWAYS'
			else p.scope		
		end as 'scope'

	into _RI_Voice_result
	from 
		_RI_Voice_result_INE_only b
			left join (
				select 
					ine as 'codigo_ine', entity_name as 'municipio',-- provincia, CCAA,
					rango_pobl, resp_sharing, scope
					--Region_OSP as 'Region_OSP',Region_VF as 'Region_VDF', replace(Provincia, '_', ' ') as Provincia_comp
				from [AGRIDS_v2].[dbo].lcc_ciudades_tipo_Project_V9 
				group by ine,entity_name, rango_pobl, resp_sharing, scope		--provincia,CCAA,zona_OSP,Zona_VF
				) p
			on p.codigo_ine=b.codigo_ine and p.municipio = b.entity

			-- FJLA 2016/09/18: se añade el estado de la medida 4G y road4G como completada en cobertura
			-- Nos quedamos con las entidades completadas
			left outer join (
				select codigo_ine, provincia, entity_name, meas_tech, meas_round, Completed
				from addedValue.[dbo].lcc_entities_completed
					union 
				select codigo_ine, provincia, entity_name, 'Cover' as meas_tech, meas_round, Completed
				from addedValue.[dbo].lcc_entities_completed 
				where meas_tech='4G'
				group by codigo_ine, provincia, entity_name,  meas_round, Completed
					union 
				select codigo_ine, provincia, entity_name, 'Road Cover' as meas_tech, meas_round, Completed
				from addedValue.[dbo].lcc_entities_completed 
				where meas_tech='Road 4G'
				group by codigo_ine, provincia, entity_name,  meas_round, Completed
			) o on b.codigo_ine=o.codigo_ine and b.meas_tech=o.meas_tech and b.meas_round=o.meas_round and b.entity=o.entity_name

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 20. Montamos la tabla -> _RI_Voice_result', getdate()

	alter table _RI_Voice_result drop column provincia, CCAA
	EXEC sp_rename '_RI_Voice_result.Provincia_V9', 'Provincia'
	EXEC sp_rename '_RI_Voice_result.CCAA_V9', 'CCAA'

	-- select * from _RI_Voice_result

	------------------------------------------------------------------------------
	-- 21. Update del MeasRound
	------------------------------------------------------------------------------
	print '21. Update del MeasRound'
	-----------
	update _RI_Voice_result
	set meas_round = 
	--	case 
	--		when convert(datetime,'1/'+SUBSTRING(meas_date,4,2)+'/20'+SUBSTRING(meas_date,1,2),103)>=convert(datetime,'01/10/2015',103)
	--				and convert(datetime,'1/'+SUBSTRING(meas_date,4,2)+'/20'+SUBSTRING(meas_date,1,2),103)<convert(datetime,'01/04/2016',103) then 'Fase 0'
	--		when convert(datetime,'1/'+SUBSTRING(meas_date,4,2)+'/20'+SUBSTRING(meas_date,1,2),103)>=convert(datetime,'01/05/2016',103) then
	--					case 
	--						when CHARINDEX ('H1',meas_round,1)>0 then 'Fase 1'
	--						when CHARINDEX ('H2',meas_round,1)>0 then 'Fase 2'
	--						when CHARINDEX ('FY1718', meas_round,1)>0 and CHARINDEX ('FY1718', meas_round,1)>0 then 'Fase 3'
	--						when convert(datetime,'1/'+SUBSTRING(meas_date,4,2)+'/20'+SUBSTRING(meas_date,1,2),103)>=convert(datetime,'01/05/2016',103)
	--							and convert(datetime,'1/'+SUBSTRING(meas_date,4,2)+'/20'+SUBSTRING(meas_date,1,2),103)<convert(datetime,'01/12/2016',103) then 'Fase 1'
	--						when convert(datetime,'1/'+SUBSTRING(meas_date,4,2)+'/20'+SUBSTRING(meas_date,1,2),103)>=convert(datetime,'01/12/2016',103)
	--							and convert(datetime,'1/'+SUBSTRING(meas_date,4,2)+'/20'+SUBSTRING(meas_date,1,2),103)<convert(datetime,'01/05/2017',103) then 'Fase 2'
	--					end
	--	end

		case 
			when convert(datetime,'1/'+SUBSTRING(meas_date,4,2)+'/20'+SUBSTRING(meas_date,1,2),103)>=convert(datetime,'01/10/2015',103)
					and convert(datetime,'1/'+SUBSTRING(meas_date,4,2)+'/20'+SUBSTRING(meas_date,1,2),103)<convert(datetime,'01/04/2016',103) then 'Fase 0'
			when convert(datetime,'1/'+SUBSTRING(meas_date,4,2)+'/20'+SUBSTRING(meas_date,1,2),103)>=convert(datetime,'01/04/2016',103) then
						case 
							
							when CHARINDEX ('FY1617_H1',meas_round,1)>0 then 'Fase 1'
							when CHARINDEX ('FY1617_H2',meas_round,1)>0 then 'Fase 2'
							when CHARINDEX ('FY1718_H1',meas_round,1)>0 then 'Fase 3'
						end
		end




  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 21. Update del MEasRound', getdate()


	------------------------------------------------------------------------------
	-- 22. Se crea la tabla _last en funcion de los indice de VODAFONE Y ORANGE:		** NUEVO- incluido VODAFONE
	------------------------------------------------------------------------------
	print '22. Se crea la tabla _last en funcion de los indice de VODAFONE Y ORANGE'
	-------------	
	--declare @rollwindowRoad as int = 4
	--declare @rollwindowAve as int = 3

	---------------------------------
	/*Como la Condición de Última medida es distinta para ambos operadores se ha creado un índice de "Last_Measurement" separado con 
	cada una de las condiciones*/
	-----------------------------------------
	exec dbo.sp_lcc_dropifexists '_RI_Voice_last'
	select r.*,
		Case when l.meas_order_vdf = 1 and id_vdf = 1 then 1 else 
			Case when (l.meas_order_vdf <= @rollwindowRoad and id_vdf = 1 and r.meas_tech like '%road%') then l.meas_order_vdf 
				when (l.meas_order_vdf <= @rollwindowAve and id_vdf = 1 and r.environment like '%ave%') then l.meas_order_vdf else 0 end
		end as last_measurement_vdf,

		Case when o.meas_order_osp = 1 and id_osp = 1 then 1 else 
			Case when (o.meas_order_osp <= @rollwindowRoad and id_osp = 1 and o.meas_tech like '%road%') then o.meas_order_osp 
				when (o.meas_order_osp <= @rollwindowAve and id_osp = 1 and r.environment like '%ave%') then o.meas_order_osp else 0 end
		end as last_measurement_osp,

		-----------------
		--last_measurement_osp para todas las medidas, COMPLETADAS o NO
		case 
			when oNC.meas_order_osp=1 and (oNC.meas_tech not like '%road%' and r.environment not like '%ave%') and id_osp_noComp = 1 then 1		-- Nos quedamos sólo con la última medida de las entidades
			when r.meas_tech like '%road%' and oNC.meas_order_osp <= @rollwindowRoad then oNC.meas_order_osp											-- Ponemos las tres últimas vueltas a 1
			when r.environment like '%ave%' and oNC.meas_order_osp <= @rollwindowAve then oNC.meas_order_osp
			else 0 
		end as last_measurement_osp_noComp,
		-----------------
		/*Quitar cuando ya no haya medidas de MAIN o SMALLER con entornos LA*/
		Case 
			when id_vdf=1 and id_osp=1 and (environment ='LA 32G' or environment ='LA 8G') and (r.SCOPE = 'MAIN CITIES' or r.SCOPE = 'SMALLER CITIES') and r.meas_date <= '16_07' then 1
			when id_vdf=1 and id_osp=0 and (environment ='LA 32G' or environment ='LA 8G') and (r.SCOPE = 'MAIN CITIES' or r.SCOPE = 'SMALLER CITIES') and r.meas_date <= '16_07'then 1
			else 0 
		end as meas_LA
  
	into _RI_Voice_last
	from _RI_Voice_result r,
	
	--************************************
	/*Creamos el meas_order para Vodafone, que luego nos servirá para obtener el Last_measurement de Vodafone*/
	   (
		select  entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type,
				row_number() over 
				(partition by entity ,mnc, meas_tech		
					order by case when Report_type = 'VDF' then report_type end desc, meas_date desc, cast(replace(meas_Week,'W','') as int) desc
				) as meas_order_vdf
		from _RI_Voice_result
		where scope not in ('RAILWAYS','MAIN HIGHWAYS') 
		group by  entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type

		--------
		union all
		select  entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type,
				row_number() over 
				(partition by entity ,mnc, meas_tech, report_type
					order by meas_date DESC, cast(replace(meas_Week,'W','') as int) desc
				) as meas_order_vdf
		from _RI_Voice_result
		where scope in ('RAILWAYS','MAIN HIGHWAYS') 
		group by  entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type
		) l,

	--************************************
	/*Creamos el meas_order para Orange, que luego nos servirá para obtener el Last_measurement de Orange*/
	-- Se modifica el orden, para que se ordene primero por FASE, luego por REPORT_TYPE y luego por FECHAS
	-- Así, se cogera la medida de la ultima fase:
	--		* cd solo haya un reporte (y si está marcado como completado), lo cogera sea VDF o MUN
	--		* cd haya los dos, cogera ordenadno por MUN-OSP-VDF
		(
		select entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type,
				row_number() over 
				(partition by  entity, mnc, meas_tech
					order by case when max(id_osp) = 1 then max(id_osp) end DESC, meas_round DESC, case when report_type = 'MUN' then report_type end DESC,
						meas_date DESC, cast(replace(meas_Week,'W','') as int) DESC					 
				 ) as meas_order_osp
		from _RI_Voice_result
		where scope not in ('RAILWAYS','MAIN HIGHWAYS') 
		group by entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type

		--------
		union all
		select entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type,
				row_number() over 
				(partition by  entity, mnc, meas_tech
					order by case when max(id_osp) = 1 then max(id_osp) end DESC, meas_round DESC, case when report_type = 'MUN' then report_type end DESC,
						meas_date DESC, cast(replace(meas_Week,'W','') as int) DESC					 
				 ) as meas_order_osp
		from _RI_Voice_result
		where scope in ('RAILWAYS','MAIN HIGHWAYS') and meas_tech not like '%cover%'
		group by entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type

		---------- EXCEPCION de la cober de carreteras y aves, en las que para OSP, ya no se presenta VDF - tienen umbrales diferentes
		union all		
		select entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type,
				row_number() over		-- este tendra valor cuando NO sea VDF para OSP
				(partition by  entity, mnc, meas_tech
					order by case when max(id_osp) = 1 then max(id_osp) end DESC, meas_round DESC, case when report_type = 'MUN' then report_type end DESC,
						meas_date DESC, cast(replace(meas_Week,'W','') as int) DESC					 
				 ) as meas_order_osp
		from _RI_Voice_result
		where scope in ('RAILWAYS','MAIN HIGHWAYS') and meas_tech like '%cover%' and report_type<>'VDF'  
		group by entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type

		--------
		union all		
		select entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type,
				0 as meas_order_osp		-- será nulo cuando sea VDF para OSP
		from _RI_Voice_result
		where scope in ('RAILWAYS','MAIN HIGHWAYS') and meas_tech like '%cover%' and report_type='VDF'  
		group by entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type

		) o,

	--************************************
	/*Creamos el meas_order para Orange, en el caso de TODAS, COMPLETADAS o NO, que luego nos servirá para obtener el Last_measurement de Orange*/
		(
		select entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type,
				row_number() over 
				(partition by entity, mnc, meas_tech
					order by case when max(id_osp_noComp) = 1 then max(id_osp_noComp) end DESC, meas_round DESC, case when report_type = 'MUN' then report_type end DESC,
						meas_date DESC, cast(replace(meas_Week,'W','') as int) DESC					 				 
				 ) as meas_order_osp
		from _RI_Voice_result
		where scope not in ('RAILWAYS','MAIN HIGHWAYS')
		group by entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type

		--------
		union all
		select entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type,
				row_number() over 
				(partition by entity, mnc, meas_tech
					order by case when max(id_osp_noComp) = 1 then max(id_osp_noComp) end DESC,  meas_round DESC, case when report_type = 'MUN' then report_type end DESC,
						meas_date DESC, cast(replace(meas_Week,'W','') as int) DESC					 				 
				 ) as meas_order_osp
		from _RI_Voice_result	
		where scope in ('RAILWAYS','MAIN HIGHWAYS') and meas_tech not like '%cover%' 
		group by entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type

		---------- EXCEPCION de la cober de carreteras y aves, en las que para OSP, ya no se presenta VDF - tienen umbrales diferentes
		union all	
		select entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type,
				row_number() over		-- este tendra valor cuando NO sea VDF para OSP
				(partition by  entity, mnc, meas_tech
					order by case when max(id_osp_noComp) = 1 then max(id_osp_noComp) end DESC, meas_round DESC, case when report_type = 'MUN' then report_type end DESC,
						meas_date DESC, cast(replace(meas_Week,'W','') as int) DESC					 
				 ) as meas_order_osp
		from _RI_Voice_result	
		where scope in ('RAILWAYS','MAIN HIGHWAYS') and meas_tech like '%cover%'  and report_type<>'VDF'
		group by entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type

		--------
		union all	
		select entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type,
				0 as meas_order_osp		-- será nulo cuando sea VDF para OSP
		from _RI_Voice_result	
		where scope in ('RAILWAYS','MAIN HIGHWAYS') and meas_tech like '%cover%'  and report_type='VDF'
		group by entity, mnc, meas_tech, meas_round, meas_date, meas_week, report_type

		) oNC

	where	r.entity = l.entity 
		and r.mnc = l.mnc
		and r.meas_tech = l.meas_tech 
		and r.meas_date = l.meas_date
		and r.meas_week = l.meas_week
		and r.report_type = l.report_type
		and r.meas_round = l.meas_round

		and o.entity = r.entity 
		and o.mnc = r.mnc
		and o.meas_tech = r.meas_tech 
		and o.meas_date = r.meas_date
		and o.meas_week = r.meas_week
		and o.report_type = r.report_type
		and o.meas_round = r.meas_round

		and oNC.entity = r.entity 
		and oNC.mnc = r.mnc
		and oNC.meas_tech = r.meas_tech 
		and oNC.meas_date = r.meas_date
		and oNC.meas_week = r.meas_week
		and oNC.report_type = r.report_type
		and oNC.meas_round = r.meas_round

  	-----------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 22. Se crea la tabla _last en funcion de los indice de VODAFONE Y ORANGE', getdate()


	-----------------------------------------------------------------------------------------------------------
	-- 23. Se prepara el resultado final 
	-----------------------------------------------------------------------------------------------------------
	print '23. Se prepara el resultado final'
	-----------
	-- Se anulan columnas en funcion del CALL_TYPE:
	update _RI_Voice_last
	set [NUMBERS OF CALLS Non Sustainability (WB)] = null,
		[MOS_Num] = NULL,
		[MOS_Samples] = NULL,
		[1_WB] = NULL,
		[2_WB] = NULL,
		[3_WB] = NULL,
		[4_WB] = NULL,
		[5_WB] = NULL,
		[6_WB] = NULL,
		[7_WB] = NULL,
		[8_WB] = NULL,
		[MOS ALL Samples WB] = NULL,
		[MOS Below 2.5 Samples WB] = NULL,
		[MOS_Samples_Under_2.5] = NULL,
		[Samples_DL+UL] = NULL,
		[WB AMR Only] = NULL,
		[Avg WB AMR Only] = NULL,
		[WB_AMR_Only_Num] = NULL,
		[WB_AMR_Only_Den] = NULL,
		[MOS_Overall_Samples_Under_2.5] = NULL
	where [calltype]='M2F'

	update _RI_Voice_last
	set [NUMBERS OF CALLS Non Sustainability (NB)] = null,
		--[1_NB] = NULL,
		--[2_NB] = NULL,
		--[3_NB] = NULL,
		--[4_NB] = NULL,
		--[5_NB] = NULL,
		--[6_NB] = NULL,
		--[7_NB] = NULL,
		--[8_NB] = NULL,
		[MOS ALL Samples NB] = NULL,
		[MOS Below 2.5 Samples NB] = NULL,
		[MOS Over 3.5 Samples NB] = NULL,	
		[MOS_NB_Samples_Under_2.5] = NULL,
		[Samples_DL+UL_NB] = NULL,
		[MOS_NB_Num] = NULL,
		[MOS_NB_Den] = NULL
	where [calltype]='M2M'

	-------------
	-- Se anulan WB AMR Only, WB_AMR_Only_Avg para YOI, ya que hay entidades agregadas con valor, y tiene q ser nulo
	update _RI_Voice_last
	set 
		[WB AMR Only] = NULL,
		[Avg WB AMR Only] = NULL,
		[WB_AMR_Only_Num] = NULL,
		[WB_AMR_Only_Den] = NULL
	where mnc=4

	-------------
	-- Se anulan los CR_Affected_Calls en todo lo que no sea AVE
	update _RI_Voice_last
		set CR_Affected_Calls = null
	where environment <> '%AVE%'

	-------------
	-- Se modifica el SCOPE de las carreteras extras - REPORT_TYPE sera ROAD
	update _RI_Voice_last
		set scope='ROAD'
	where report_type='ROAD'

	-- select * from _RI_Voice_last

	declare @last_measurement as varchar(50)
--declare @rollwindowRoad as int = 4
--declare @rollwindowAve as int = 3

	-------------------------------------------
	-- 22.1 Primero se lanza el codigo para VDF:		
	-------------------------------------------
	set @last_measurement='last_measurement_vdf'

	-- 1º)	Se lanza para AVEs - VDF:
	exec [QLIK].dbo.plcc_Replicas_review_VX 'AVE','AddedValue','_RI_Voice_last','Voice', @last_measurement, @rollwindowAve

	-- Se guarda el resultado del proc anterior:
	exec dbo.sp_lcc_dropifexists '_RI_Voice_Completed_LastAVE'

	Select * into _RI_Voice_Completed_LastAVE from [QLIK].[dbo].[_Completed_Review_RI_Voice]

	-- 2º)	Se lanza para ROADS - VDF:
	exec [QLIK].dbo.plcc_Replicas_review_VX 'Roads','AddedValue','_RI_Voice_Completed_LastAVE','Voice', @last_measurement, @rollwindowRoad
	
	-- 3º)	Se guarda el resultado final - VDF - step1:
	If (select name from [QLIK].sys.tables where name = '_RI_Voice_Completed_Qlik_step1') is not null
	begin
		drop table [QLIK].[dbo].[_RI_Voice_Completed_Qlik_step1]
	end
	Select *
	into [QLIK].[dbo].[_RI_Voice_Completed_Qlik_step1]
	from [QLIK].[dbo].[_Completed_Review_RI_Voice]

	-------------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 23.1 Actualizadas vueltas de AVE y ROADs para VDF', getdate()

	-------------------------------------------
	-- 22.2 Luego se lanza el codigo para OSP:
	-------------------------------------------
	set @last_measurement='last_measurement_osp'

	-- 4º)	Se lanza para AVEs - OSP:
	exec [QLIK].dbo.plcc_Replicas_review_VX 'AVE','QLIK','_RI_Voice_Completed_Qlik_step1','Voice', @last_measurement, @rollwindowAve

	-- Se guarda el resultado del proc anterior:
	exec dbo.sp_lcc_dropifexists '_RI_Voice_Completed_LastAVE'
	Select * into _RI_Voice_Completed_LastAVE from [QLIK].[dbo].[_Completed_Review_RI_Voice]

	-- 5º)	Se lanza para ROADS - OSP:
	exec [QLIK].dbo.plcc_Replicas_review_VX 'Roads','AddedValue','_RI_Voice_Completed_LastAVE','Voice', @last_measurement, @rollwindowRoad
	
	-- 6º)	Se guarda el resultado final - VDF y OSP:
	If (select name from [QLIK].sys.tables where name = '_RI_Voice_Completed_Qlik') is not null
	begin
		drop table [QLIK].[dbo].[_RI_Voice_Completed_Qlik]
	end
	Select *
	into [QLIK].[dbo].[_RI_Voice_Completed_Qlik]
	from [QLIK].[dbo].[_Completed_Review_RI_Voice]

	-------------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin 23.2 Actualizadas vueltas de AVE y ROADs para VDF y OSP', getdate()


	---------------------------------------------
	---- 22.3 Se borran las tablas temporales			
	---------------------------------------------
	-- Se borran las tablas por si quedara una ejecucion incompleta:
	exec dbo.sp_lcc_dropifexists '_RI_Voice_c'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_m'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cst'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cst_csfb'

	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober4G'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober2G'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober3G'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober4G'

	exec dbo.sp_lcc_dropifexists '_RI_Voice_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober3G_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober2G_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_cober4G_Pob_Entidad'

	exec dbo.sp_lcc_dropifexists '_RI_Voice_base'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base1'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result1'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result_INE_only'

	exec dbo.sp_lcc_dropifexists '_RI_Voice_base_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_i_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base1_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result1_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result2_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_result1_info'

	exec dbo.sp_lcc_dropifexists '_RI_Voice_base_report_Pob_Entidad'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_base_x'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_last'

	-------------------------------------
	-- Borramos las tablas intermedias de Qlik:
	exec dbo.sp_lcc_dropifexists '_RI_Voice_Completed'
	exec dbo.sp_lcc_dropifexists '_RI_Voice_Completed_LastAVE'
	If (select name from [QLIK].sys.tables where name = '_RI_Voice_Completed_Qlik_step1') is not null
	begin
		drop table [QLIK].[dbo].[_RI_Voice_Completed_Qlik_step1]
	end
	If (select name from [QLIK].sys.tables where name = '_Completed_Review_RI_Voice') is not null
	begin
		drop table [QLIK].[dbo].[_Completed_Review_RI_Voice]
	end

	-------------
	insert into [dbo].[_RI_Voice_Ejecucion]
	select 'Fin Ejecucion RI para QLIK', getdate()

end		-- fin @result='Q'

-- ************************************************************************************************************************************

else			-- trabajamos para @result='D' o @result='E'
begin

	-- Cogemos la tabla de Qlik para trabajar con ella - ya tiene en cuenta las vueltas de AVEs y Roads
	-- drop table #RI_Voice_last_Qlik
	select * into #RI_Voice_last_Qlik from [QLIK].[dbo].[_RI_Voice_Completed_Qlik]
	
	-------------
	-- Se descartan las medidas antiguas:
	delete #RI_Voice_last_Qlik
	where Meas_Date in ('16_04','15_07','15_08','15_09')

	---------------
	-- Borramos las columnas de los rangos del CST y MOS:
	alter table #RI_Voice_last_Qlik drop column 
		[1_MO_A],	[2_MO_A],	[3_MO_A],	[4_MO_A],	[5_MO_A],	[6_MO_A],	[7_MO_A],	
		[8_MO_A],	[9_MO_A],	[10_MO_A],	[11_MO_A],	[12_MO_A],	[13_MO_A],	[14_MO_A],	
		[15_MO_A],	[16_MO_A],	[17_MO_A],	[18_MO_A],	[19_MO_A],	[20_MO_A],	[21_MO_A],	
		[22_MO_A],	[23_MO_A],	[24_MO_A],	[25_MO_A],	[26_MO_A],	[27_MO_A],	[28_MO_A],	
		[29_MO_A],	[30_MO_A],	[31_MO_A],	[32_MO_A],	[33_MO_A],	[34_MO_A],	[35_MO_A],
		[36_MO_A],	[37_MO_A],	[38_MO_A],	[39_MO_A],	[40_MO_A],	[41_MO_A],

		[1_MT_A],	[2_MT_A],	[3_MT_A],	[4_MT_A],	[5_MT_A],	[6_MT_A],	[7_MT_A],	
		[8_MT_A],	[9_MT_A],	[10_MT_A],	[11_MT_A],	[12_MT_A],	[13_MT_A],	[14_MT_A],	
		[15_MT_A],	[16_MT_A],	[17_MT_A],	[18_MT_A],	[19_MT_A],	[20_MT_A],	[21_MT_A],	
		[22_MT_A],	[23_MT_A],	[24_MT_A],	[25_MT_A],	[26_MT_A],	[27_MT_A],	[28_MT_A],	
		[29_MT_A],	[30_MT_A],	[31_MT_A],	[32_MT_A],	[33_MT_A],	[34_MT_A],	[35_MT_A],	
		[36_MT_A],	[37_MT_A],	[38_MT_A],	[39_MT_A],	[40_MT_A],	[41_MT_A],

		[1_MOMT_A],		[2_MOMT_A],		[3_MOMT_A],		[4_MOMT_A],		[5_MOMT_A],		[6_MOMT_A],	
		[7_MOMT_A],		[8_MOMT_A],		[9_MOMT_A],		[10_MOMT_A],	[11_MOMT_A],	[12_MOMT_A],	
		[13_MOMT_A],	[14_MOMT_A],	[15_MOMT_A],	[16_MOMT_A],	[17_MOMT_A],	[18_MOMT_A],	
		[19_MOMT_A],	[20_MOMT_A],	[21_MOMT_A],	[22_MOMT_A],	[23_MOMT_A],	[24_MOMT_A],	
		[25_MOMT_A],	[26_MOMT_A],	[27_MOMT_A],	[28_MOMT_A],	[29_MOMT_A],	[30_MOMT_A],
		[31_MOMT_A],	[32_MOMT_A],	[33_MOMT_A],	[34_MOMT_A],	[35_MOMT_A],	[36_MOMT_A],
		[37_MOMT_A],	[38_MOMT_A],	[39_MOMT_A],	[40_MOMT_A],	[41_MOMT_A],
			
		[1_MO_C],	[2_MO_C],	[3_MO_C],	[4_MO_C],	[5_MO_C],	[6_MO_C],	[7_MO_C],	
		[8_MO_C],	[9_MO_C],	[10_MO_C],	[11_MO_C],	[12_MO_C],	[13_MO_C],	[14_MO_C],	
		[15_MO_C],	[16_MO_C],	[17_MO_C],	[18_MO_C],	[19_MO_C],	[20_MO_C],	[21_MO_C],	
		[22_MO_C],	[23_MO_C],	[24_MO_C],	[25_MO_C],	[26_MO_C],	[27_MO_C],	[28_MO_C],	
		[29_MO_C],	[30_MO_C],	[31_MO_C],	[32_MO_C],	[33_MO_C],	[34_MO_C],	[35_MO_C],
		[36_MO_C],	[37_MO_C],	[38_MO_C],	[39_MO_C],	[40_MO_C],	[41_MO_C],

		[1_MT_C],	[2_MT_C],	[3_MT_C],	[4_MT_C],	[5_MT_C],	[6_MT_C],	[7_MT_C],	
		[8_MT_C],	[9_MT_C],	[10_MT_C],	[11_MT_C],	[12_MT_C],	[13_MT_C],	[14_MT_C],	
		[15_MT_C],	[16_MT_C],	[17_MT_C],	[18_MT_C],	[19_MT_C],	[20_MT_C],	[21_MT_C],	
		[22_MT_C],	[23_MT_C],	[24_MT_C],	[25_MT_C],	[26_MT_C],	[27_MT_C],	[28_MT_C],	
		[29_MT_C],	[30_MT_C],	[31_MT_C],	[32_MT_C],	[33_MT_C],	[34_MT_C],	[35_MT_C],
		[36_MT_C],	[37_MT_C],	[38_MT_C],	[39_MT_C],	[40_MT_C],	[41_MT_C],

		[1_MOMT_C],		[2_MOMT_C],		[3_MOMT_C],		[4_MOMT_C],		[5_MOMT_C],		[6_MOMT_C],	
		[7_MOMT_C],		[8_MOMT_C],		[9_MOMT_C],		[10_MOMT_C],	[11_MOMT_C],	[12_MOMT_C],	
		[13_MOMT_C],	[14_MOMT_C],	[15_MOMT_C],	[16_MOMT_C],	[17_MOMT_C],	[18_MOMT_C],	
		[19_MOMT_C],	[20_MOMT_C],	[21_MOMT_C],	[22_MOMT_C],	[23_MOMT_C],	[24_MOMT_C],	
		[25_MOMT_C],	[26_MOMT_C],	[27_MOMT_C],	[28_MOMT_C],	[29_MOMT_C],	[30_MOMT_C],
		[31_MOMT_C],	[32_MOMT_C],	[33_MOMT_C],	[34_MOMT_C],	[35_MOMT_C],	[36_MOMT_C],
		[37_MOMT_C],	[38_MOMT_C],	[39_MOMT_C],	[40_MOMT_C],	[41_MOMT_C]

	alter table #RI_Voice_last_Qlik drop column 
		[1_WB],	[2_WB],	[3_WB],	[4_WB],	[5_WB],	[6_WB],	[7_WB],	[8_WB],
		[1_NB],	[2_NB],	[3_NB],	[4_NB],	[5_NB],	[6_NB],	[7_NB],	[8_NB]

	-- Borramos las mil columnas de zonas y regiones innecesarias:
	alter table #RI_Voice_last_Qlik drop column Region_Road_VF, Region_Road_OSP		-- zona_VDF, zona_OSP,

	-- Borramos la columna de Report_Type:
	--alter table #RI_Voice_last_Qlik drop column Report_Type

	----------------------------------------------------------------- 
	-- Ahora separamos en funcion del cliente, ya que ira al DASH o al excel del RI:
	-------------
	if @client=1 
	begin 

		-- Nos quedamos con la columna de last_measurement de VDF, y SOLO las medidas de VDF (id_vdf=1)
		select 
			*,last_measurement_vdf as last_measurement, Region_VF as Zona,		--REPLACE(Region_VF, 'R', 'Zona') as Zona, --zona_VDF as Zona, Region_Road_VF as Region_Road, 
			case 
					when meas_Tech like 'Cover' and environment in ('MAIN HIGHWAYS', 'ROADS' , 'RURAL') then 'Rural'
					when meas_Tech like 'Cover' and environment in ('MAIN', 'SMALLER' , 'ADDON', 'TOURISTIC', 'ROC') then 'Urban'

					-- Para entidades ROADs y AVEs: 
					when meas_Tech like 'Road Cover' and environment in ('MAIN HIGHWAYS', 'ROADS' , 'RURAL') then 'Roads'
					when meas_Tech like 'Cover' and environment in ('AVE') then 'AVEs'

			end as environment_ResultCober
		into #RI_Voice_last_vf
		from #RI_Voice_last_Qlik
		where id_vdf=1		-- ojo que va a sacar las ultimas de YTB SD y NoCA_Device, son medidas antiguas

		-- Borramos la info de carreteras extras ya que van solo para OSP:
		delete #RI_Voice_last_vf
		where Report_Type='ROAD'

		-- Borramos las sobrantes - de OSP:
		alter table #RI_Voice_last_vf drop column id_osp, id_osp_noComp, last_measurement_osp, last_measurement_osp_noComp, id_vdf, last_measurement_vdf, Region_VF, Region_OSP

		-- Borramos la columna de Report_Type:
		alter table #RI_Voice_last_vf drop column Report_Type

		--******************************************************************************
		-- Se presenta el resultado final:
		if @result='D'	-- resultado para DASH				
		begin
			select d.ENTITIES_DASHBOARD, l.* 
			from #RI_Voice_last_vf l
				LEFT OUTER JOIN (select distinct entities_bbdd, ENTITIES_DASHBOARD from AGRIDs.dbo.vlcc_dashboard_info_scopes_NEW where report='VDF') d
					on l.entity=d.entities_bbdd
			-- nos quedamos con la ultima medida y los agregados de roads y aves que se indiquen como parametro
			where ((last_measurement >0 and last_measurement<=@rollwindowRoad) or  (last_measurement >0 and last_measurement<=@rollwindowAve))
				and d.ENTITIES_DASHBOARD is not null
		end

		if @result='E'	-- resultado para Excel RI			
		begin
			select l.*		-- nos quedamos todas las medidas - se podra filtrar en el excel por last_measurement=1
			from #RI_Voice_last_vf l
		end
		--******************************************************************************		
		drop table #RI_Voice_last_vf, #RI_Voice_last_Qlik		
	end		

	-------------
	if @client=3
	begin
		if @isCompleted='Y'		-- queremos la info de las COMPLETADAS para OSP
		begin
			-- Nos quedamos con la columna de last_measurement_osp y SOLO las medidas de OSP (id_osp=1 - medidas COMPLETADAS)
			select 
				*, last_measurement_osp as last_measurement, Region_OSP as Zona,		--REPLACE(Region_OSP, 'R', 'Zona') as Zona,	--zona_OSP as Zona, Region_Road_OSP as Region_Road, 
				case 
					when meas_Tech like 'Cover' and environment in ('MAIN HIGHWAYS', 'ROADS' , 'RURAL') then 'Rural'
					when meas_Tech like 'Cover' and environment in ('MAIN', 'SMALLER' , 'ADDON', 'TOURISTIC', 'ROC') then 'Urban'

					-- Para entidades ROADs y AVEs: 
					when meas_Tech like 'Road Cover' and environment in ('MAIN HIGHWAYS', 'ROADS' , 'RURAL') then 'Roads'
					when meas_Tech like 'Cover' and environment in ('AVE') then 'AVEs'

				end as environment_ResultCober
			into #RI_Voice_last_osp_Y
			from #RI_Voice_last_Qlik
			where id_osp=1					-- esto sería para medidas COMPLETADAS (por OSP, por ambos o por uno de los 2)	

			-- Borramos medidas VOLTE ya que van solo para VDF:
			delete #RI_Voice_last_osp_Y
			where meas_Tech like 'VOLTE%'

			-- Borramos las sobrantes - de OSP:
			alter table #RI_Voice_last_osp_Y drop column id_vdf, id_osp, id_osp_noComp, last_measurement_osp, last_measurement_osp_noComp, last_measurement_vdf, Region_VF, Region_OSP --, zona_OSP, zona_VDF, Region_Road_VF, Region_Road_OSP

			-- Borramos la columna de Report_Type:
			alter table #RI_Voice_last_osp_Y drop column Report_Type

			--******************************************************************************	
			-- Se presenta el resultado final:
			if @result='D'	-- resultado para DASH				
			begin
				select d.ENTITIES_DASHBOARD, l.* 
				from #RI_Voice_last_osp_Y l
					LEFT OUTER JOIN (select distinct entities_bbdd, ENTITIES_DASHBOARD from AGRIDs.dbo.vlcc_dashboard_info_scopes_NEW where report='MUN') d
						on l.entity=d.entities_bbdd
				-- nos quedamos con la ultima medida y los agregados de roads y aves que se indiquen como parametro
				where ((last_measurement >0 and last_measurement<=@rollwindowRoad) or  (last_measurement >0 and last_measurement<=@rollwindowAve))	
					and d.ENTITIES_DASHBOARD is not null
			end

			if @result='E'	-- resultado para Excel RI			
			begin
				select l.*	-- nos quedamos todas las medidas - se podra filtrar en el excel por last_measurement=1
				from #RI_Voice_last_osp_Y l

			end
			--******************************************************************************		
			drop table #RI_Voice_last_osp_Y, #RI_Voice_last_Qlik		

		end	
		
		else					-- queremos TODAS las medidas, COMPLETADAS o NO
		begin
			-- Nos quedamos con la columna de last_measurement_osp_noComp y SOLO las medidas de OSP (COMPLETADAS o no)
			select 
				*,last_measurement_osp_noComp as last_measurement, Region_OSP as Zona,	--REPLACE(Region_OSP, 'R', 'Zona') as Zona,--zona_OSP as Zona, 
				case 
					-- Para las entidades ciudades - en INDOOR van sin scanner:
					when meas_Tech like 'Cover' and environment in ('MAIN HIGHWAYS', 'ROADS' , 'RURAL') then 'Rural'
					when meas_Tech like 'Cover' and environment in ('MAIN', 'SMALLER' , 'ADDON', 'TOURISTIC', 'ROC') then 'Urban'

					-- Para entidades ROADs y AVEs: 
					when meas_Tech like 'Road Cover' and environment in ('MAIN HIGHWAYS', 'ROADS' , 'RURAL') then 'Roads'
					when meas_Tech like 'Cover' and environment in ('AVE') then 'AVEs'

				end as environment_ResultCober
			into #RI_Voice_last_osp
			from #RI_Voice_last_Qlik
			where id_osp_noComp=1			-- esto serían todas las medidas para OSP, completadas o no

			-- Borramos medidas VOLTE ya que van solo para VDF:
			delete #RI_Voice_last_osp
			where meas_Tech like 'VOLTE%'

			-- Borramos las sobrantes - de OSP:
			alter table #RI_Voice_last_osp drop column id_vdf, id_osp, id_osp_noComp, last_measurement_osp, last_measurement_osp_noComp, last_measurement_vdf, Region_VF, Region_OSP --, zona_OSP, zona_VDF, Region_Road_VF, Region_Road_OSP


			--******************************************************************************	
			-- Se presenta el resultado final:
			if @result='D'	-- resultado para DASH				
			begin
				select d.ENTITIES_DASHBOARD, l.*
				into #final 
				from #RI_Voice_last_osp l
					LEFT OUTER JOIN (select distinct entities_bbdd, ENTITIES_DASHBOARD from AGRIDs.dbo.vlcc_dashboard_info_scopes_NEW where report='MUN') d
						on l.entity=d.entities_bbdd
				-- nos quedamos con la ultima medida y los agregados de roads y aves que se indiquen como parametro
				where ((last_measurement >0 and last_measurement<=@rollwindowRoad) or  (last_measurement >0 and last_measurement<=@rollwindowAve))	
					 and (d.ENTITIES_DASHBOARD is not null or l.report_type='ROAD')

				-- Borramos la columna de Report_Type - lo hacemos aqui porque hacen falta en la intruccion anterior
				alter table #final drop column Report_Type

				-- Resultado final:
				select * from #final
			end

			if @result='E'	-- resultado para Excel RI			
			begin
				-- Borramos la columna de Report_Type:
				alter table #RI_Voice_last_osp drop column Report_Type

				select l.*	-- nos quedamos todas las medidas - se podra filtrar en el excel por last_measurement=1
				from #RI_Voice_last_osp l					
			end
			--******************************************************************************		
			drop table #RI_Voice_last_osp, #RI_Voice_last_Qlik, #final	
		end
	end
end		-- fin @result='D' o @result='E'
