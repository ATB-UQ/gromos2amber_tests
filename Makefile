
TEST_CASES := \
    1177_H2O_vacuum 1177_H2O_liquid \
    3798_H2O_vacuum 3798_H2O_liquid \
    1907_aa_H2O_vacuum \
    32084_aa_H2O_vacuum \
    34231_aa_H2O_vacuum \
    32785_aa_H2O_vacuum \
    31084_aa_H2O_vacuum \
    24070_aa_H2O_vacuum \
    4482_aa_H2O_vacuum \
    34239_aa_H2O_vacuum \
    32133_aa_H2O_vacuum \
    33786_aa_H2O_vacuum \
    820_aa_H2O_vacuum \
    34011_aa_H2O_vacuum \
    764_aa_H2O_vacuum \
    32177_aa_H2O_vacuum \
    32084_ua_H2O_vacuum \
    34231_ua_H2O_vacuum \
    32785_ua_H2O_vacuum \
    31084_ua_H2O_vacuum \
    24070_ua_H2O_vacuum \
    4482_ua_H2O_vacuum \
    34239_ua_H2O_vacuum \
    32133_ua_H2O_vacuum \
    33786_ua_H2O_vacuum \
    820_ua_H2O_vacuum \
    34011_ua_H2O_vacuum \
    764_ua_H2O_vacuum \
    32177_ua_H2O_vacuum \
    54A7_1a19_md_rep_3 \
    54a7_1ng6 \
    54a7_1qqv \
    54a7_1tua \
    54a7_1ucs \
    54a7_1zvg \
    DLPC_H2O_512_bilayer \
    DLPC_noH2O_512_bilayer

# The earliest version that should give idential prmtop and inpcrd files
BASELINE_VERSION := 0.2.0-dev

PRMTOPS := $(foreach X,$(TEST_CASES),amber_prmtop/$X.prmtop)
PRMTOP_DIFFS := $(foreach X,$(TEST_CASES),amber_prmtop_diff/$X.prmtop.diff)
INPCRDS := $(foreach X,$(TEST_CASES),amber_inpcrd/$X.inpcrd)
INPCRD_DIFFS := $(foreach X,$(TEST_CASES),amber_inpcrd_diff/$X.inpcrd.diff)
AENERGY := $(foreach X,$(TEST_CASES),sander_energy/$X.energy)
TRES := $(foreach X,$(TEST_CASES),gromos_energy/$X.tre)
IMDS := $(foreach X,$(TEST_CASES),temp/$X.imd)
YAML := $(foreach X,$(TEST_CASES),gromos_energy/$X.yml) \
    $(foreach X,$(TEST_CASES),sander_energy/$X.yml) \
    $(foreach X,$(TEST_CASES),pmemd_energy/$X.yml)
COMPARE := $(foreach X,$(TEST_CASES),$X_compare)
GROMOS2AMBER := ../gromos2amber
SOLVFLAG_TEST := DLPC_H2O_512_bilayer

.PHONY : test
test : $(PRMTOPS) $(PRMTOP_DIFFS) $(INPCRDS) $(INPCRD_DIFFS) \
    temp/$(SOLVFLAG_TEST)_solvent_flag.prmtop

.PHONY : validate
validate : $(PRMTOPS) $(AENERGY) $(TRES) $(YAML) $(COMPARE) $(IMDS)

DIRS := temp amber_prmtop amber_inpcrd \
    sander_energy gromos_energy amber_prmtop_diff amber_inpcrd_diff \
    pmemd_energy

.PHONY : dirs
dirs :
	mkdir -p $(DIRS)

amber_prmtop/%.prmtop : $(GROMOS2AMBER) \
    gromos_top/%.top gromos_cnf/%.cnf | dirs
	./$< \
	    --config_in $(word 3,$^) \
	    --config_out amber_inpcrd/$*.inpcrd \
	    < $(word 2,$^) > $@

temp/$(SOLVFLAG_TEST)_solvent_flag.prmtop : \
    $(GROMOS2AMBER) \
    amber_prmtop/$(SOLVFLAG_TEST).prmtop \
    gromos_top/$(SOLVFLAG_TEST).top
	$< --num_solvent 16632 < $(word 3,$^) > $@
	diff -q $@ $(word 2,$^)

# Fails if prmtops differ from baseline version
amber_prmtop_diff/%.prmtop.diff : \
    amber_prmtop/%.prmtop amber_prmtop_v$(BASELINE_VERSION)/%.prmtop
	diff $< $(word 2,$^) > $@

amber_inpcrd_diff/%.inpcrd.diff : \
    amber_inpcrd/%.inpcrd amber_inpcrd_v$(BASELINE_VERSION)/%.inpcrd
	diff $< $(word 2,$^) > $@

# dummy recipe, this target is created along with the prmtop
amber_inpcrd/%.inpcrd : amber_prmtop/%.prmtop
	touch $@

temp/%_vacuum.sander.in : vacuum.sander.in | dirs
	cp $< $@

temp/%_liquid.sander.in : liquid.sander.in | dirs
	cp $< $@

temp/%.sander.in : standard.sander.in | dirs
	cp $< $@

temp/%_vacuum.pmemd.in : vacuum.pmemd.in | dirs
	cp $< $@

temp/%_liquid.pmemd.in : liquid.pmemd.in | dirs
	cp $< $@

temp/%.pmemd.in : standard.pmemd.in | dirs
	cp $< $@

temp/%_vacuum.imd : vacuum.gromos.imd gromos_cnf/%_vacuum.cnf | dirs
	./make_imd $(word 2,$^) 3 < $< > $@

temp/%_liquid.imd : liquid.gromos.imd gromos_cnf/%_liquid.cnf | dirs
	./make_imd $(word 2,$^) 3 < $< > $@

temp/%.imd : standard.gromos.imd gromos_cnf/%.cnf | dirs
	./make_imd $(word 2,$^) 3 < $< > $@

sander_energy/%.energy: temp/%.sander.in amber_prmtop/%.prmtop amber_inpcrd/%.inpcrd
	sander -O -i $< \
	    -o temp/$*.sander.log \
	    -p $(word 2,$^) \
	    -c $(word 3,$^) \
	    -r temp/$*.sander.rstrt \
	    -x temp/$*.sander.mdcrd \
	    -frc temp/$*.sander.mdfrc \
	    -inf temp/$*.sander.mdinfo -e $@

pmemd_energy/%vacuum.energy: \
    temp/%vacuum.pmemd.in amber_prmtop/%vacuum.prmtop \
    amber_inpcrd/%vacuum.inpcrd
	head -n-1 $(word 3,$^) > temp/$*vacuum.inpcrd
	echo '   100.00000   100.00000   100.00000' >> temp/$*vacuum.inpcrd
	pmemd -O -i $< \
	    -o temp/$*vacuum.pmemd.log \
	    -p $(word 2,$^) \
	    -c temp/$*vacuum.inpcrd \
	    -r temp/$*vacuum.pmemd.rstrt \
	    -x temp/$*vacuum.pmemd.mdcrd \
	    -frc temp/$*vacuum.pmemd.mdfrc \
	    -inf temp/$*vacuum.pmemd.mdinfo -e $@

pmemd_energy/%.energy: temp/%.pmemd.in amber_prmtop/%.prmtop amber_inpcrd/%.inpcrd
	pmemd -O -i $< \
	    -o temp/$*.pmemd.log \
	    -p $(word 2,$^) \
	    -c $(word 3,$^) \
	    -r temp/$*.pmemd.rstrt \
	    -x temp/$*.pmemd.mdcrd \
	    -frc temp/$*.pmemd.mdfrc \
	    -inf temp/$*.pmemd.mdinfo -e $@

gromos_energy/%.tre : temp/%.imd \
    gromos_top/%.top gromos_cnf/%.cnf
	md \
	    \@input $< \
	    \@topo $(word 2,$^) \
	    \@conf $(word 3,$^) \
	    \@fin  temp/$*.final.cnf \
	    \@trc  temp/$*.trc \
	    \@tre  $@ > temp/$*.gromos.log

gromos_format.py : ../lib/gromos_format.py
	cp $< $@

gromos_energy/%.yml : gromos_energy/%.tre gromos_format.py
	./parse_gromos_energy < $< > $@

sander_energy/%.yml : sander_energy/%.energy
	./parse_amber_energy < $< > $@

pmemd_energy/%.yml : pmemd_energy/%.energy
	./parse_amber_energy < $< > $@

%_compare : pmemd_energy/%.yml sander_energy/%.yml gromos_energy/%.yml
	echo $* && \
	    ./compare_energies $^


.PHONY : clean
clean :
	rm -rf $(DIRS) gromos_format.py *.pyc
