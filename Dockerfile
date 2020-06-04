FROM ruby:2.6-alpine3.11
ENV GEM_HOME="/usr/local/bundle"
ENV PATH $GEM_HOME/bin:$GEM_HOME/gems/bin:$PATH
RUN gem install bundler -v '2.1.4' && gem list
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY ./src/ ./src
COPY ./tests/ ./tests
COPY ./system_tests/ ./system_tests
COPY ./Rakefile ./