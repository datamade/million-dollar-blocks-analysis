include config.mk

.PHONY: all clean

blocks_variable = geoid10
chicomm_variable = distitle 

all: mil-dol-blocks-total.zip mil-dol-chicomm-total.zip

clean: 
	rm people.* charges.* 
	rm blocks.dbf  blocks.prj blocks.shp  blocks.shx CensusBlockTIGER2010.*
	rm original_* 
	rm addresses.csv addresses.vrt
	rm *.table

reset_db :
	psql -U $(PG_USER) -h $(PG_HOST) -p $(PG_PORT) -d $(PG_DB) -c \
	"DROP TABLE IF EXISTS people"
	psql -U $(PG_USER) -h $(PG_HOST) -p $(PG_PORT) -d $(PG_DB) -c \
	"DROP TABLE IF EXISTS charges"
	psql -U $(PG_USER) -h $(PG_HOST) -p $(PG_PORT) -d $(PG_DB) -c \
	"DROP TABLE IF EXISTS expected_life"
	psql -U $(PG_USER) -h $(PG_HOST) -p $(PG_PORT) -d $(PG_DB) -c \
	"DROP TABLE IF EXISTS days_sentenced"
	psql -U $(PG_USER) -h $(PG_HOST) -p $(PG_PORT) -d $(PG_DB) -c \
	"DROP TABLE IF EXISTS addresses"
	rm *.table

##########################################
# NOTE:                                  #
# REQUEST_11-0058_Criminal_2005-2009.txt #
# is the raw data that’s not included in #
# this repo due to its sensitive nature  #
##########################################

people.txt: REQUEST\ 11-0058\ Criminal\ 2005-2009.txt
	cat "$<" | grep "^[0].*"  > $@

charges.txt: REQUEST\ 11-0058\ Criminal\ 2005-2009.txt
	cat "$<" | grep "^[^0].*"  > $@

%.csv: %.txt
	in2csv -s $*_schema.csv $< > $*.csv

categorized_charges.csv : charges.csv 
	python label_charges.py

%.table: %.csv
	csvsql --db "postgresql://$(PG_USER)@$(PG_HOST):$(PG_PORT)/$(PG_DB)" \
		--no-constraints --tables $* $<
	cat $< | psql -U $(PG_USER) -h $(PG_HOST) -p $(PG_PORT) -d $(PG_DB) -c \
		"COPY $* FROM STDIN CSV HEADER"
	touch $@

addresses.csv: address_matching_output.csv
	 cat $< | \
		awk -F',' '{printf $$0 ",\n"}' | \
		(echo "messy_address,canonical_address,score,longitude,latitude,original_address" ; tail -n +2 ) > $@

%.vrt : %.csv
	@echo \
	\<OGRVRTDataSource\>\
	  \<OGRVRTLayer name=\"$*\"\>\
	    \<SrcDataSource\>$<\</SrcDataSource\>\
	    \<GeometryType\>wkbPoint\</GeometryType\>\
	    \<LayerSRS\>WGS84\</LayerSRS\>\
	    \<GeometryField encoding=\"PointFromColumns\" x=\"longitude\" y=\"latitude\"/\>\
	  \</OGRVRTLayer\>\
	\</OGRVRTDataSource\> > $@

addresses.table : addresses.vrt
	ogr2ogr -f "PostgreSQL" -lco GEOMETRY_NAME=geom -lco FID=gid \
	PG:"host=$(PG_HOST) port=$(PG_PORT) dbname=$(PG_DB)" \
	$< -nln $(basename $<)
	@touch $@

blocks.zip :
	wget -O $@ "https://data.cityofchicago.org/api/geospatial/mfzt-js4n?method=export&format=Original"
	touch $@

chicomm.zip : 
	wget -O $@ http://www.lib.uchicago.edu/e/collections/maps/chicomm.zip
	touch $@

chicomm.shp : chicomm.zip
	unzip -o $<

.INTERMEDIATE : original_blocks.shp
original_blocks.shp : blocks.zip
	unzip -o $<
	rename 's/CensusBlockTIGER2010/$(basename $@)/' *.*
	touch $@

%.shp : original_%.shp
	ogr2ogr -s_srs EPSG:3435 -t_srs EPSG:4326 -f "ESRI Shapefile" $@ $<
	touch $@

%.table : %.shp
	shp2pgsql -I -s 4326 -d $< $* | \
	psql -U $(PG_USER) -h $(PG_HOST) -p $(PG_PORT) -d $(PG_DB)
	touch $@

expected_life.table : categorized_charges.table people.table
	psql -U $(PG_USER) -h $(PG_HOST) -p $(PG_PORT) -d $(PG_DB) -c \
	"CREATE TABLE expected_life AS \
       	 (SELECT DISTINCT case_number, \
               		  (76*365.25 \
                           - (to_date(charge_disp_date::text, 'YYYYMMDD') \
                              - to_date(date_of_birth::text, 'YYYYMMDD') \
                              ) \
                           )::INT AS expected_life_left \
          FROM people INNER JOIN categorized_charges USING (case_number) \
          WHERE date_of_birth != 0)"
	touch $@

days_sentenced.table : expected_life.table
	psql -U $(PG_USER) -h $(PG_HOST) -p $(PG_PORT) -d $(PG_DB) -c \
        "CREATE TABLE days_sentenced AS \
         (SELECT case_number, charge_disp, \
                 COALESCE(amended_charge_bin, original_charge_bin) AS charge_bin, \
                 to_date(charge_disp_date::text, 'YYYYMMDD') AS disp_date, \
       	         CASE WHEN min_sentence IN ('88888888', '99999999') \
                      THEN expected_life_left \
                      ELSE LEAST(expected_life_left, \
                                 ( \
                                  SUBSTRING(min_sentence, 1, 3)::INT*365.25 \
                                  + SUBSTRING(min_sentence, 4, 2)::INT*30.4375 \
                                  + SUBSTRING(min_sentence, 6, 3)::INT \
                                  ) \
                                 ) \
                 END AS days \
          FROM categorized_charges INNER JOIN expected_life USING (case_number) \
         )"
	psql -U $(PG_USER) -h $(PG_HOST) -p $(PG_PORT) -d $(PG_DB) -c \
	"CREATE INDEX charge_idx ON days_sentenced (charge_disp)"
	touch $@

mil-dol-%-total.shp : %.table days_sentenced.table addresses.table
	pgsql2shp -f $@ -h $(PG_HOST) -u $(PG_USER) -p $(PG_PORT) $(PG_DB) \
	"SELECT $($*_variable),  \
         ((SUM(CASE WHEN charge_bin = 'Violent' \
                    THEN conservative_days \
                    ELSE 0 \
               END)/365) * 21000)::INT AS violent_cost, \
         ((SUM(CASE WHEN charge_bin = 'Drug' \
                    THEN conservative_days \
                    ELSE 0 \
               END)/365) * 21000)::INT AS drug_cost, \
         ((SUM(CASE WHEN charge_bin = 'Nonviolent' \
                    THEN conservative_days \
                    ELSE 0 \
               END)/365) * 21000)::INT AS nonviolent_cost, \
         ((SUM(conservative_days)/365) * 21000)::INT AS total_cost, \
         $*.geom \
	 FROM people, addresses, $*, \
         (SELECT case_number, charge_bin, \
                 max_min_sentence - max_credit AS conservative_days \
          FROM \
          (SELECT case_number, SUM(days) AS max_credit \
           FROM days_sentenced \
           WHERE charge_disp = 'CREDIT DEFENDANT FOR TIME SERV' \
           GROUP BY case_number) AS max_credit \
          INNER JOIN \
	  (SELECT days_sentenced.case_number, max_min_sentence, charge_bin \
	   FROM days_sentenced, \
           (SELECT case_number, MAX(days) AS max_min_sentence \
            FROM days_sentenced \
            WHERE charge_disp = 'DEF SENTENCED ILLINOIS DOC' \
            GROUP BY case_number) AS t_min_sentence \
           WHERE charge_disp = 'DEF SENTENCED ILLINOIS DOC' \
           AND days_sentenced.case_number = t_min_sentence.case_number \
           AND days_sentenced.days = t_min_sentence.max_min_sentence) \
           AS min_sentence \
          USING (case_number)) AS sentence_length \
         WHERE people.case_number = sentence_length.case_number \
               AND people.street_address = addresses.original_address \
               AND addresses.canonical_address IS NOT NULL \
               AND st_contains($*.geom, addresses.geom) \
               AND conservative_days > 0 \
         GROUP BY $($*_variable), $*.geom"

%.zip : %.shp
	zip $@ $*.*
