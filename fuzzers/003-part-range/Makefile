N := 1
# SPECIMENS = specimen_001
SPECIMENS := $(addprefix specimen_,$(shell seq -f '%03.0f' $(N)))

database: $(SPECIMENS)
	cp specimen_001/tile_map.txt ${XRAY_DATABASE_DIR}/$(XRAY_DATABASE)/${XRAY_PART}_tile_map.txt
	cp specimen_001/device_rows.txt ${XRAY_DATABASE_DIR}/$(XRAY_DATABASE)/${XRAY_PART}_device_rows.txt

$(SPECIMENS): Makefile.specimen
	mkdir -p $@
	$(MAKE) -C $@ -f ../Makefile.specimen

pushdb:
	cp ${XRAY_PART}_tile_map.txt ${XRAY_DATABASE_DIR}/$(XRAY_DATABASE)

run:
	$(MAKE) clean
	$(MAKE) database
	$(MAKE) pushdb
	touch run.ok

clean:
	rm -rf specimen_[0-9][0-9][0-9]/ *.yaml run.ok *.log *.jou

.PHONY: database pushdb clean run $(SPECIMENS)
