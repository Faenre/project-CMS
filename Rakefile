require "rake/testtask"

desc 'Run the test files'
Rake::TestTask.new(:test) do |t|
  t.libs << 'app'
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

desc 'Test cleanup'
task :test_cleanup do
  print 'Cleaning up...'
  `git checkout -- './test/data'`
  puts 'done'
end

desc 'Run tests (default)'
task default: [:test, :test_cleanup]
