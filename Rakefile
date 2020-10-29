require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << 'app'
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

desc 'Run tests (default)'
task default: [:test]
