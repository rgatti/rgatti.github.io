start-dev-server:
    hugo server -D

create-post POST:
    hugo new content content/posts/{{POST}}/index.md
