FROM hugomods/hugo:exts AS builder
COPY . /src
RUN hugo --minify

FROM hugomods/hugo:nginx
COPY --from=builder /src/public /site
