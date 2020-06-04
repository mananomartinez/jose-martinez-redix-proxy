
.PHONY : test

test: setup runtests teardown

runtests: rununittests runsystemtests

setup:
	$(info ************  SETTING UP  ************)
	docker-compose up -d

rununittests:
	$(info ************  RUNNING UNIT TESTS ************)
	docker-compose run --rm redis-proxy-tests bundle exec rake test

runsystemtests: 
	$(info ************  RUNNING SYSTEM TESTS ************)
	docker-compose run --rm redis-proxy-tests bundle exec rake system_tests

teardown:
	$(info ************  TEARING DOWN ************)
	docker-compose down
