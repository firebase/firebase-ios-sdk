FROM ruby:3.4.1

# Create a non-root user
RUN groupadd -g 1001 appgroup && \
    useradd -r -u 1001 -g appgroup -m -l appuser

RUN gem install bundler:2.6.2
RUN mkdir /myapp && chown appuser:appgroup /myapp
WORKDIR /myapp
COPY --chown=appuser:appgroup Gemfile /myapp/Gemfile
COPY --chown=appuser:appgroup Gemfile.lock /myapp/Gemfile.lock
RUN bundle install
COPY --chown=appuser:appgroup . /myapp

USER appuser

ENTRYPOINT [ "ruby", "/myapp/app.rb" ]
