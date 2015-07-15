# Chicago Million Dollar Blocks

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

# Results

Images from QGIS using Jenks Natural Breaks based on total person years per block:

![Mockup 1](https://raw.githubusercontent.com/datamade/chi-million-dollar-blocks/master/images/million-dollar-blocks-mockup-1.png?token=AA4IH6s9XNAlWO9xU2A4SEoBs8kKyLitks5U7mDVwA%3D%3D)

![Mockup 2](https://raw.githubusercontent.com/datamade/chi-million-dollar-blocks/master/images/million-dollar-blocks-mockup-2.png?token=AA4IH25IsN1RT3P1RbB8tCsHd43Hn7OXks5U7mFEwA%3D%3D)
