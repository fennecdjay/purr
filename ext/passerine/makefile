
$(LIB)/libpurr_passerine.so: $(LIB)/libpurr_passerine.o
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$@ $^ $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

$(LIB)/libpurr_passerine.o: dummy $(LIB)
	$(eval OBJECTS+=$@)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) $(REALOCATON_MODE_TO_PIC) -c $(call dlangsrc,ext/passerine,plugin.d) -Ipurr -Iext $(DC_CMD_OUT_FLAG)$@ 
