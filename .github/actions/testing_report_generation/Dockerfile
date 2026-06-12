FROM ruby:2.7.2

# Create a non-root user
RUN groupadd -g 1001 appgroup && \
    useradd -r -u 1001 -g appgroup -m -l appuser

RUN gem install bundler:1.17.2
RUN mkdir /myapp
WORKDIR /myapp
COPY --chown=appuser:appgroup Gemfile /myapp/Gemfile
COPY --chown=appuser:appgroup Gemfile.lock /myapp/Gemfile.lock
RUN bundle install
COPY --chown=appuser:appgroup . /myapp

USER appuser

ENTRYPOINT [ "ruby", "/myapp/app.rb" ]
