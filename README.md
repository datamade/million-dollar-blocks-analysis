# Chicago Million Dollar Blocks

This repo contains the analysis behind the [Chicago Million Dollar Blocks project](http://chicagosmilliondollarblocks.com/)

The convictions data comes from the Chicago Justice Project - for more information, see [Convicted In Cook](http://convictions.smartchicagoapps.org/)

This repo does not contain the exact data that we used, which has sensitive information - namely, addresses. However, there is an [anonymized version of the convictions dataset](https://drive.google.com/folderview?id=0B_aXS4x_XvJmSVlLNUJqREpCUG8&usp=sharing).

# Setup
```bash
> createdb jail
> psql -d jail -c "CREATE EXTENSION postgis"
```

Install stuff using pip & [homebrew](http://brew.sh/)
```bash
> pip install -r requirements.txt
> brew install gdal --with-postgresql
```

Mac users: you will also need the rename library

```bash
> brew install rename
```

Copy the config.mk.example to config.mk:

```bash
> cp config.mk.example config.mk
```

Configure make in `config.mk` with your DB settings, then:

```bash
> make
```
