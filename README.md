# jupyter-gap
Jupyter kernels for GAP 

Please note that this software is still in the early stages of development and names of kernels, assumptions,
and architecture might change on a day-to-day basis without notice.

## wrapper-kernel

The `wrapper-kernel` is a Jupyter kernel based on the [bash wrapper kernel](https://github.com/takluyver/bash_kernel),
to install

```shell
    python setup.py install
    python -m jupyter_gap_wrapper.install
```

To use it, use one of the following:

```shell
    jupyter notebook
    jupyter qtconsole --kernel gap
    jupyter console --kernel gap
```

Note that this kernel requires you to set the environment variable `JUPYTER_GAP_EXECUTABLE` to a valid gap executable or `gap.sh` script.
