from setuptools import setup, find_namespace_packages


if __name__ == "__main__":

    namespace = "rockefeg"
    pkg = "cyutil"


    setup(
        name = "{namespace}.{pkg}".format(**locals()),
        version='0.0.0',
        ext_modules = [],
        zip_safe=False,
        packages=find_namespace_packages("src"),
        package_dir={'': 'src'},
        install_requires=['cython', 'numpy'],
        script_args = ["develop"],
        namespace_packages = [namespace],
        python_requires = ">=3.3")
