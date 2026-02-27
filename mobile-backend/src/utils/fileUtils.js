export const getFilePath = (file) => {
    if (!file) return null;
    // If uploaded to S3, use location URL. Otherwise use file path.
    return file.location || `/${file.path.replace(/\\/g, '/')}`;
};
