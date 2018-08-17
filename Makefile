PROJECT=can4docker
TIMESTAMP:=$(shell date +"%Y%m%d%H%M%S")

MAX_COMPLEXITY=A
MIN_MAINTANABILITY=A


default:
	@egrep '(^##)|(^[^[:blank:]]*:)' Makefile

venv: FORCE
	@if [ -e venv ]; then echo "a 'venv' directory already exists, please delete it first."; false; fi
	@echo Creating a virtual python environement ...
	@virtualenv -p python3 venv > /dev/null
	@echo Updating pip and setuptools ...
	@. venv/*/activate; python -m pip install --upgrade pip setuptools > /dev/null
	@echo Installing pip requirements ...
	@. venv/*/activate; pip install $$(cat requirements/*pip-requirements.txt) > /dev/null
	@echo Your virtual env is now ready, you stil need to activate it, eg:
	@echo $$ . $$(ls venv/*/activate)

#################################################################################
## Sanity checkers
#################################################################################
## targets are designed to be run from a bare shell (no venv), typically in the 
## pipeline, for each target, there is a version that starts with a '_', that
## can be run if your already in a venv (typically developper)

##
## pycodestyle
##
check_pep8:
	python -m pycodestyle --show-source --show-pep8 --statistics $(PROJECT) tests

venv_check_pep8: FORCE
	./scripts/within_venv -r checks \
	make check-pep8

pip_check_pep8: FORCE
	./scripts/with_pip -r checks \
	make check_pep8


##
## pylint
##
check_lint: FORCE
	PYTHONPATH=$$PWD:$$PYTHONPATH \
	pylint --errors-only --output-format parseable $(PROJECT) tests

venv_check_lint: FORCE
	./scripts/within_venv -r checks -r $(PROJECT) \
	make check_lint

pip_check_lint: FORCE
	./scripts/with_pip -r checks -r $(PROJECT) \
	make check_lint

##
## radon (currently there's no B in the code, so let's try to keep it this way)
##
check_complexity:
	radon cc --max $(MAX_COMPLEXITY) --show-complexity --average $(PROJECT)
	radon mi --min $(MIN_MAINTANABILITY) --show $(PROJECT)

venv_check_complexity:
	./scripts/within_venv -r checks \
	make check_complexity

pip_check_complexity:
	./scripts/with_pip -r checks \
	make check_complexity


##
## all (for developper convenience, if you pass this, you should pass the
##     pipeline "Sanity checks" stage. Fastests checks are executed first)
##
check_all: check_pep8 check_complexity check_lint
pip_check_all: pip_check_pep8 pip_check_complexity pip_check_lint
venv_check_all: venv_check_pep8 venv_check_complexity venv_check_lint


#################################################################################
## Documentation
#################################################################################
## 
build_doc:
	export PYTHONPATH=$$PWD:$$PYTHONPATH && \
	make -C docs/ html

venv_build_doc: FORCE
	./scripts/within_venv -r docs -r $(PROJECT) \
	make build-doc

pip_build_doc: FORCE
	./scripts/with_pip -r docs -r $(PROJECT) \
	make build-doc


#################################################################################
## Packaging as python wheel and docker image
#################################################################################
## 

build_package: FORCE
	python setup.py bdist_wheel
	rm -Rf build/ $(PROJECT).egg-info/
	ls -l dist/

venv_build_package: FORCE
	./scripts/within_venv -r packaging \
	make build_package

pip_build_package: FORCE
	./scripts/with_pip -r packaging \
	make build_package

build_container: FORCE
	true

venv_build_container: FORCE
	true

pip_build_container: FORCE
	true

#################################################################################
## Deploy package, documentation and docker images to a testing/staging area
#################################################################################
## TODO: Make sure to attempt a pip install with correct version

deploy_package_staging: FORCE
	./scripts/within_venv -r packaging \
	twine upload -u $(TWINE_USERNAME) -p $(TWINE_PASSWORD) \
		--repository-url https://test.pypi.org/legacy/ dist/*
	./scripts/within_venv \
		"pip install --index-url https://test.pypi.org/simple/ \
		--extra-index-url https://pypi.org/simple $(PROJECT) && \
		python -c 'import can4docker; print(can4docker.__name__)'"


#################################################################################
## Cleaning up
#################################################################################
## Clean will remove any files generated by the check targets
# TBD: should it clean any files generated by any make targets?
clean: FORCE
	rm -Rf TEST-* COVERAGE-* METRIC-*
	rm -Rf docs/_build/

FORCE:
