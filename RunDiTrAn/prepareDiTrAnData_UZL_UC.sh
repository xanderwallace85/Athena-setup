docker login harbor.athenafederation.org

docker pull harbor.athenafederation.org/distributed-analytics/event-generator:0.2.4
docker pull harbor.athenafederation.org/distributed-analytics/analysis-table-generator-uc:1.1.3
docker pull harbor.athenafederation.org/athena-restricted/ditran-data-pipeline-uc:1.5.0

echo "run 'predefined' event generator"
docker run --rm --network feder8-net -v ${PWD}/results/predefined_events:/script//analysis_table_results --env THERAPEUTIC_AREA=athena --env INDICATION=uc --env EVENT_CONFIG_FILENAME=uc_event_model --env STUDY_LOGIC=uzl_uc --env EPISODE_TABLE_SCHEMA=results --env LOGGING=INFO --env EPISODE_TABLE_NAME=predefined_episode_table_uc harbor.athenafederation.org/distributed-analytics/event-generator:0.2.4

echo "run 'derived' event generator"
docker run --rm --network feder8-net -v ${PWD}/results/derived_events:/script/analysis_table_results --env THERAPEUTIC_AREA=athena --env INDICATION=uc --env STUDY_LOGIC=uzl_uc --env EPISODE_TABLE_SCHEMA=results --env LOGGING=INFO --env EPISODE_TABLE_NAME=derived_episode_table_uc harbor.athenafederation.org/distributed-analytics/event-generator:0.2.4

echo "create analysis table with predefined events"
docker run --rm --network feder8-net -v ${PWD}/results/predefined_analysis:/script/results --env THERAPEUTIC_AREA=athena --env INDICATION=uc --env VERSION=1.1.3 --env ANALYSIS_TABLE_SCHEMA=results --env ANALYSIS_TABLE_NAME=predefined_analysis_table_uc --env EXPOSURE_TABLE_SCRIPT=exposure_uc_omop53 --env DERIVATE_TABLE_SCRIPT=derivate_uc --env OUTCOME_TABLE_SCRIPT=outcome_uc --env EPISODE_TABLE_SCHEMA=results --env EPISODE_TABLE_NAME=predefined_episode_table_uc --env COVARIATE_CONFIGURATION=configuration_uc harbor.athenafederation.org/distributed-analytics/analysis-table-generator-uc:1.1.3

echo "create analysis table with derived events"
docker run --rm --network feder8-net -v ${PWD}/results/derived_analysis:/script/results  --env THERAPEUTIC_AREA=athena --env INDICATION=uc --env VERSION=1.1.3 --env ANALYSIS_TABLE_SCHEMA=results --env ANALYSIS_TABLE_NAME=derived_analysis_table_uc --env EXPOSURE_TABLE_SCRIPT=exposure_uc_omop53 --env DERIVATE_TABLE_SCRIPT=derivate_uc --env OUTCOME_TABLE_SCRIPT=outcome_uc --env EPISODE_TABLE_SCHEMA=results --env EPISODE_TABLE_NAME=derived_episode_table_uc --env COVARIATE_CONFIGURATION=configuration_uc harbor.athenafederation.org/distributed-analytics/analysis-table-generator-uc:1.1.3

echo "correct DB permissions if needed"
docker exec -it postgres psql -U postgres -d OHDSI -c "REASSIGN OWNED BY feder8_admin TO ohdsi_admin;REASSIGN OWNED BY ohdsi_app_user TO ohdsi_app;"
echo "combine analysis tables"
docker exec -it postgres psql -U postgres -d OHDSI -c "DROP TABLE IF EXISTS results.combined_analysis_table_uc;CREATE TABLE results.combined_analysis_table_uc as select *, 'predefined' as event_type from results.predefined_analysis_table_uc union select *, 'derived' as event_type from results.derived_analysis_table_uc;"

echo "run DiTrAn pipeline script"
docker run --rm --network feder8-net -v ${PWD}/results/ditran:/script/shareable_results --name disease-explorer-data-preparation -v disease-explorer-config:/pipeline/data --env THERAPEUTIC_AREA=athena --env INDICATION=uc --env DB_ANALYSIS_TABLE_SCHEMA=results --env DB_ANALYSIS_TABLE_NAME=combined_analysis_table_uc --env PIPELINE_CONFIGURATION=uc --env CONFIG_FILENAME=journey_configuration_combined --env LOGGING=INFO harbor.athenafederation.org/athena-restricted/ditran-data-pipeline-uc:1.5.0

echo "end of pipeline"

