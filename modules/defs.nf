// join multiple channels based on one or several keys
def multijoin(x, by){
    def result = x[0];
    int i;
    for(i=1 ; i < x.size(); i++){
        result = result.combine(x[i], by: by)
    }
    return result
}
