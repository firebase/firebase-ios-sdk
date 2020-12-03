FROM ruby:2.7.2

RUN gem install bundler:1.17.2
RUN mkdir /myapp
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
RUN bundle install
COPY . /myapp

ENTRYPOINT [ "ruby", "/myapp/app.rb" ]
