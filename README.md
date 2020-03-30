# cyutil
Cython utility module

WARNING: Each Array shares its view only with a unique exporting object. This lets the Array expand freely without corrupting data. Do not change the view manually (e.g. Don't: arr.view = np.ndarray((3,))).

TODO testing
TODO documentation