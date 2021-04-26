from setuptools import setup
import sys

if __name__ == "__main__":

    namespace = "goldenrockefeller"
    pkg = "cyutil"
    name = "{namespace}.{pkg}".format(**locals())

    setup(
        name = name,
        version='0.0.0',
        zip_safe=False,
        packages=[namespace, name],
        package_dir={'': 'src'},
        install_requires=['cython', 'numpy'],
        package_data={"": ["*.pxd", "*.pyx", "*.pyxbld"]},
        python_requires = ">=3.3")
