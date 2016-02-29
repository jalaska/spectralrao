######### SPECTRAL RAO #############################
## Code to calculate Rao's quadratic entropy on a
## numeric matrix, RasterLayer object (or lists)
## using a moving window. The function also calculates
## Shannon diversity index.
## Rao's Q Min = 0, if all pixel classes have
## distance 0. If the chosen distance ranges between
## 0 and 1, Rao's Max = 1-1/S (Simpson Diversity,
## where S is pixel classes).
## Last update: 29th February
#####################################################

#Function
spectralrao<-function(matrix,distance_m="euclidean",window=3,mode="classic",shannon=TRUE) {

#Change input matrix/ces names
    if(is(matrix,"matrix") | is(matrix,"RasterLayer") ) {
        rasterm<-matrix
    } else if(is(matrix,"list")) {
        rasterm<-matrix[[1]]
    }

#Load required packages
    require(raster)

#Deal with matrix and RasterLayer in a different way
    if( is(matrix[[1]],"RasterLayer") ) {
        if(mode=="classic"){
            rasterm<-round(as.matrix(rasterm),2)
            message("RasterLayer ok: \n Rao and Shannon output matrices will be returned")
        }else if(mode=="multidimension" & shannon==FALSE){
            message(("RasterLayer ok: \n A raster object with multimension RaoQ will be returned"))
        }else if(mode=="multidimension" & shannon==TRUE){
            stop(("Matrix check failed: \n multidimension and Shannon not compatible, set shannon=FALSE"))
        }
    }else if( is(matrix,"matrix") | is(matrix,"list") ) {
        if(mode=="classic"){
            message("Matrix check ok: \n Rao and Shannon output matrices will be returned")
        }else if(mode=="multidimension" & shannon==FALSE){
            message(("Matrix check ok: \n A matrix with multimension RaoQ will be returned"))
        }else if(mode=="multidimension" & shannon==TRUE){
            stop("Matrix check failed: \n multidimension and Shannon not compatible, set shannon=FALSE")
        }else{stop("Matrix check failed: \n Not a valid input, please provide a matrix, list or RasterLayer object")
    }
}

#Calculate operational moving window
oddn<-seq(1,window,2)
oddn_pos<-which(oddn == 3)
w=window-oddn_pos

#Output matrices preparation
raoqe<-matrix(rep(NA,dim(rasterm)[1]*dim(rasterm)[2]),nrow=dim(rasterm)[1],ncol=dim(rasterm)[2])
shannond<-matrix(rep(NA,dim(rasterm)[1]*dim(rasterm)[2]),nrow=dim(rasterm)[1],ncol=dim(rasterm)[2])
#
#If classic RaoQ
#
if(mode=="classic"){
#Reshape values
    values<-as.numeric(as.factor(rasterm))
    rasterm_1<-matrix(data=values,nrow=dim(rasterm)[1],ncol=dim(rasterm)[2])

#Add fake columns and rows for moving window
    hor<-matrix(NA,ncol=dim(rasterm)[2],nrow=w)
    ver<-matrix(NA,ncol=w,nrow=dim(rasterm)[1]+w*2)
    trasterm<-cbind(ver,rbind(hor,rasterm_1,hor),ver)
#Derive distance matrix
    classes<-levels(as.factor(rasterm))
    d1<-dist(classes,method=distance_m)
#Loop over each pixel
    for (cl in (1+w):(dim(rasterm)[2]+w)) {
        for(rw in (1+w):(dim(rasterm)[1]+w)) {
            tw<-summary(as.factor(trasterm[c(rw-w):c(rw+w),c(cl-w):c(cl+w)]),maxsum=10000)
            if("NA's" %in% names(tw)) {
                tw<-tw[-length(tw)]
            }
            tw_labels<-names(tw)
            tw_values<-as.vector(tw)
            if(length(tw_values) == 1) {
                raoqe[rw-w,cl-w]<-0
            }else{p<-tw_values/sum(tw_values)
            p1<-combn(p,m=2,FUN=prod)
            d2<-as.matrix(d1)
            d2[upper.tri(d1,diag=TRUE)]<-NA
            d3<-d2[as.numeric(tw_labels),as.numeric(tw_labels)]
            raoqe[rw-w,cl-w]<-sum(p1*d3[!(is.na(d3))])
        }
    }
} # End classic RaoQ
} else if(mode=="multidimension"){
#
#If multimensional RaoQ
#
#Reshape values
    vls<-lapply(matrix, function(x) {as.matrix(x)})
#Add fake columns and rows for moving w
    hor<-matrix(NA,ncol=dim(vls[[1]])[2],nrow=w)
    ver<-matrix(NA,ncol=w,nrow=dim(vls[[1]])[1]+w*2)
    trastersm<-lapply(vls, function(x) {cbind(ver,rbind(hor,x,hor),ver)})

# Function to extract the center value of a matrix
    ctpoint<-function(x,...){x[round(dim(x)[1]/2),round(dim(x)[2]/2)]
}

# Loop over all the pixels in the matrices
for (cl in (1+w):(dim(vls[[1]])[2]+w)) {
    for(rw in (1+w):(dim(vls[[1]])[1]+w)) {
        tw<-lapply(trastersm, function(x) {x[(rw-w):(rw+w),(cl-w):(cl+w)]})
        raoqe[rw-w,cl-w] <- sapply(Reduce('+',sum(do.call(cbind,lapply(tw, function(x) {(x-ctpoint(x))^2 })),na.rm=TRUE)), function(y) {y*(1/(window)^2)})
    }
} # end multimensional RaoQ
}
#
#ShannonD
#
if(shannon==TRUE){
    #Reshape values
    values<-as.numeric(as.factor(rasterm))
    rasterm_1<-matrix(data=values,nrow=dim(rasterm)[1],ncol=dim(rasterm)[2])

#Add fake columns and rows for moving window
    hor<-matrix(NA,ncol=dim(rasterm)[2],nrow=w)
    ver<-matrix(NA,ncol=w,nrow=dim(rasterm)[1]+w*2)
    trasterm<-cbind(ver,rbind(hor,rasterm_1,hor),ver)

#Loop over all the pixels
    for (cl in (1+w):(dim(rasterm)[2]+w)) {
        for(rw in (1+w):(dim(rasterm)[1]+w)) {
            tw<-summary(as.factor(trasterm[c(rw-w):c(rw+w),c(cl-w):c(cl+w)]))
            tw_values<-as.vector(tw)
            p<-tw_values/sum(tw_values)
            p_log<-log(p)
            shannond[rw-w,cl-w]<-(-(sum(p*p_log)))
        }
    } # End ShannonD
}
#
#Return the output
#
if( is(rasterm,"RasterLayer") ) {
    if( shannon==TRUE) {
#Rasterize the matrices if matrix==raster
        rastertemp <- stack(raster(raoqe, template=matrix),raster(shannond, template=raster))
    } else if(shannon==FALSE){
        rastertemp <- raster(raoqe, template=rasterm)
    }
}
#
#Return different outputs
#
if( is(rasterm,"RasterLayer") ) {
    return(rastertemp)
} else if( !is(rasterm,"RasterLayer") & shannon==TRUE ) {
    return(list(raoqe,shannond))
} else if( !is(rasterm,"RasterLayer") & shannon==FALSE ) {
    return(list(raoqe))
}
}
