test:
	nvim --headless -u ./tests/minimal_init.lua -i NONE -n --noplugin -c 'PlenaryBustedDirectory tests'
