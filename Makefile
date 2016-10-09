
TEST_CASES := \
    1177_H2O_vacuum 1177_H2O_liquid \
    3798_H2O_vacuum 3798_H2O_liquid \
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
    DLPC_H2O_512_bilayer \
    DLPC_noH2O_512_bilayer
 
PRMTOPS := $(foreach X,$(TEST_CASES),amber_prmtop/$X.prmtop)
AENERGY := $(foreach X,$(TEST_CASES),amber_energy/$X.energy)
TRES := $(foreach X,$(TEST_CASES),gromos_energy/$X.tre)
IMDS := $(foreach X,$(TEST_CASES),temp/$X.imd)
YAML := $(foreach X,$(TEST_CASES),gromos_energy/$X.yml) \
    $(foreach X,$(TEST_CASES),amber_energy/$X.yml)
COMPARE := $(foreach X,$(TEST_CASES),$X_compare)
GROMOS2AMBER := ../gromos2amber

.PHONY : test
test : $(PRMTOPS) $(AENERGY) $(TRES) $(YAML) $(COMPARE) $(IMDS)

DIRS := temp amber_prmtop amber_inpcrd amber_energy gromos_energy

.PHONY : dirs
dirs :
	mkdir -p $(DIRS)

temp/%_vacuum.in : vacuum.amber.in | dirs
	cp $< $@

temp/%_liquid.in : liquid.amber.in | dirs
	cp $< $@

temp/%_bilayer.in : bilayer.amber.in | dirs
	cp $< $@

temp/%_vacuum.imd : vacuum.gromos.imd gromos_cnf/%_vacuum.gromos.cnf | dirs
	./make_imd $(word 2,$^) 3 < $< > $@

temp/%_liquid.imd : liquid.gromos.imd gromos_cnf/%_liquid.gromos.cnf | dirs
	./make_imd $(word 2,$^) 3 < $< > $@

temp/%_bilayer.imd : bilayer.gromos.imd gromos_cnf/%_bilayer.gromos.cnf | dirs
	./make_imd $(word 2,$^) 3 < $< > $@

amber_prmtop/%.prmtop : $(GROMOS2AMBER) \
    gromos_top/%.gromos.top gromos_cnf/%.gromos.cnf | dirs
	./$< $(word 2,$^) $(word 3,$^) \
		$@ amber_inpcrd/$*.inpcrd

amber_energy/%.energy: temp/%.in amber_prmtop/%.prmtop amber_inpcrd/%.inpcrd
	sander -O -i $< \
	    -o temp/$*.amber.log \
	    -p $(word 2,$^) \
	    -c $(word 3,$^) \
	    -r temp/$*.rstrt -inf \
	    -x temp/$*.mdcrd -inf \
	    temp/$*.mdinfo -e $@

gromos_energy/%.tre : temp/%.imd \
    gromos_top/%.gromos.top gromos_cnf/%.gromos.cnf
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

amber_energy/%.yml : amber_energy/%.energy
	./parse_amber_energy < $< > $@

%_compare : amber_energy/%.yml gromos_energy/%.yml
	echo $* && \
	    ./compare_energies $< $(word 2,$^)


.PHONY : clean
clean :
	rm -rf $(DIRS) gromos_format.py *.pyc
