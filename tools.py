import pandas as pd
import numpy as np


def get_file(path_name):
    """return a dataFrame from cvs file
    Args:
        path_name ([str]): path to the file
    Returns:
        [dataFrame]
    """
    return pd.read_csv(path_name)
