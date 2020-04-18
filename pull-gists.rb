
require 'io/console'
require 'ostruct'
require 'logger'
require 'etc'
require 'thread'
require 'http'

def h2o h
  JSON.parse(JSON.generate(h), object_class: OpenStruct)
end

def o2h o, h={}
  o.each_pair { |k, v| h[k] = (OpenStruct === v ? (o2h v) : v) }; h
end

url = 'https://api.github.com'
print 'Input your GitHub API token (hidden): '
token = STDIN.noecho(&:gets).chomp
puts
@client = HTTP[Accept: 'application/json']
  .use(logging: { logger: Logger.new(STDOUT).tap { |l| l.level = :info } })
  .auth("token #{token}")
  .persistent(url)
  .via('localhost', 1080)

def q query
  json = { query: "{ #{query} }" }
  res = @client.post '/graphql', json: json
  ret = h2o res.parse
  ret.errors&.tap { |e|
    puts "#{e.type} #{e.path.join(' > ')}"
    puts e.message
    exit 1
  }
  return ret.data
end

def download_gists_json
  gists = []
  user = (q %{ viewer { login } }).viewer.login
  puts "login: #{user}"
  endCursor = nil
  hasNextPage = true
  while hasNextPage
    result = q %{
      user(login: #{user.inspect}) {
        gists(first: 100#{", after: #{endCursor.inspect}" if endCursor}) {
          nodes {
            url,
            description
          }
          pageInfo {
            endCursor,
            hasNextPage
          }
        }
      }
    }
    gists.concat result.user.gists.nodes
    result.user.gists.pageInfo.tap { |i|
      endCursor = i.endCursor
      hasNextPage = i.hasNextPage
    }
  end
  File.write 'gists.json', JSON.generate(gists.map { |e| o2h e })
ensure
  @client.close
end

download_gists_json unless File.exist? 'gists.json'
gists = h2o JSON.parse File.read 'gists.json'
queue = Queue.new
num_workers = Etc.nprocessors
threads = Array.new(num_workers) { |i|
  Thread.new {
    until (h = queue.pop) == :END
      folder = h.url[/\h{32}/]
      next if Dir.exist? folder
      puts "[#{i}] #{folder[0, 8]} #{h.description}"
      proxy = '-c http.proxy=http://localhost:1080'
      system "git clone #{h.url}.git #{proxy}", out: File::NULL, err: File::NULL
    end
  }
}
gists.each { |gist| queue << gist }
num_workers.times { queue << :END }
threads.each(&:join)
