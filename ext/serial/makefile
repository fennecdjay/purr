
$(LIB)/libpurr_serial.so: $(LIB)/libpurr_serial.o
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$@ $^ $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

$(LIB)/libpurr_serial.o: dummy $(LIB) $(TMP)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) $(REALOCATON_MODE_TO_PIC) -c $(call dlangsrc,ext/serial,plugin.d) -Ipurr -Iext $(DC_CMD_OUT_FLAG)$(LIB)/libpurr_serial.o
