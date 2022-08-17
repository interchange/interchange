# To run a local Interchange demo using Docker

1. Clone this repository into a new directory and create subdirectories for `catalogs` and `server`

2. Copy interchange/docker/docker-compose.yml to the new directory

```
new directory
-> catalogs/
-> docker-compose.yml
-> interchange/
-> server/
```

3. Run `docker-compose build` then `docker-compose up`

4. Go to http://localhost:4242/demo

## Log in to admin

Go to http://localhost:4242/demo/admin - default login is interchange:pass

## Watching log files

The Plack access log will be displayed in the terminal where you run `docker-compose up`

To watch interchange logs, log into the container with `docker exec -it <new directory>_interchange_1 bash` and run `tail -f interchange/*.log catalogs/demo/logs/*`

## Modify catalog and server files

You can modify any of the files in the catalogs/ and server/ directories and your changes will not be overwritten when restarting the container.

If you want to reset the files to default, remove all of the files in the catalogs/ and server/ directories and restart the container.

## Restarting the Interchange server

To restart the Interchange server you do not need to restart the container. Log into the container with `docker exec -it <new directory>_interchange_1 bash` and then run `interchange/bin/interchange -r`

## Add a new catalog

To add a new catalog, log into the container with `docker exec -it <new directory>_interchange_1 bash` and run `cd interchange && bin/makecat`

Then modify the `catalogs/app.psgi` file:
* add the catalog to the static files path
```
      enable 'Static',
      path => qr{^/(demo|<new catalog>)/(images|js|css|interchange-5)/},
            root => '/home/interchange/catalogs/static/';
```
* add a mount entry for the new catalog
```
mount '/<new catalog>' => Plack::App::WrapCGI->new( script => '/home/interchange/catalogs/bin/<new catalog>', execute => 1 )->to_app;
```

You will need to restart the container to access the new catalog at `http://localhost:4242/<new catalog>`

