require "rake/testtask"

Rake::TestTask.new do |t|
  t.name = 'test'
  t.test_files = FileList['tests/**/*_tests.rb']
  t.verbose = true
  t.warning = true
end

desc "Run tests"

Rake::TestTask.new do |t|
  t.name = 'system_tests'
  t.test_files = FileList['system_tests/*_tests.rb']
  t.verbose = true
  t.warning = true
end

task default: :test
