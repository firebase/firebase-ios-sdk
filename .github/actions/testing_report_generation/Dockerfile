FROM ruby:2.7.2

# Create a non-root user
RUN groupadd -g 1001 appgroup && \
    useradd -r -u 1001 -g appgroup appuser

RUN gem install bundler:1.17.2
RUN mkdir /myapp
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
RUN bundle install
COPY . /myapp

# Ensure the appuser owns the application files
RUN chown -R appuser:appgroup /myapp

USER appuser

ENTRYPOINT [ "ruby", "/myapp/app.rb" ]
